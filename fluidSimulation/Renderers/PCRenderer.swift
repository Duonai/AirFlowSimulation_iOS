import Metal
import MetalKit
import ARKit

final class PCRenderer {
    // additional code
    let pointThresh:Int = 7

    var viewPaused: Bool = false
    var renderRGB: Bool = false
    var sessionPaused: Bool = false
    var gridCreated: Bool = false
    
    var gridLengthX : Float = 0.0 //gridLength
    var gridLengthY : Float = 0.0 //gridHeight
    var gridLengthZ : Float = 0.0 //gridWidth
    
    var cornerArray:[SCNVector3] = [] //for corner detection
    var imagePos:simd_float3 = simd_float3(0,0,0) //for image detection
    var pxLen:Float = 0.0
    var mxLen:Float = 0.0
    var pyLen:Float = 0.0
    var myLen:Float = 0.0
    
    var rotationValue:Float = 0.0
    
    var boundary_points:[Float]! //max_x, min_x, max_z, min_z
    var pc_max_y : Float = 0.0
    var pc_min_y : Float = 0.0
    
    //occupancy grid
    var gridArray:[Grid]!
    var gridSizeX:Int = 0
    var gridSizeY:Int = 0
    var gridSizeZ:Int = 0
    
    var boolGrid:[Bool]!
    
    // Maximum number of points we store in the point cloud
    private let maxPoints = 10_000_000
    // Number of sample points on the grid
    private let numGridPoints = 500
    // Particle's size in pixels
    private let particleSize: Float = 5
    // We only use landscape orientation in this app
    private let orientation = UIInterfaceOrientation.landscapeRight
    // Camera's threshold values for detecting when the camera moves so that we can accumulate the points
    private let cameraRotationThreshold = cos(2 * .degreesToRadian)
    private let cameraTranslationThreshold: Float = pow(0.02, 2)   // (meter-squared)
    // The max number of command buffers in flight
    private let maxInFlightBuffers = 3
    
    private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
    private let session: ARSession
    
    // Metal objects and textures
    private let device: MTLDevice
    private let library: MTLLibrary
    //private let renderDestination: RenderDestinationProvider
    private let sceneView: ARSCNView
    private let relaxedStencilState: MTLDepthStencilState
    private let depthStencilState: MTLDepthStencilState
    private let commandQueue: MTLCommandQueue
    private lazy var unprojectPipelineState = makeUnprojectionPipelineState()!
    private lazy var rgbPipelineState = makeRGBPipelineState()!
    private lazy var particlePipelineState = makeParticlePipelineState()!
    // texture cache for captured image
    private lazy var textureCache = makeTextureCache()
    private var capturedImageTextureY: CVMetalTexture?
    private var capturedImageTextureCbCr: CVMetalTexture?
    private var depthTexture: CVMetalTexture?
    private var confidenceTexture: CVMetalTexture?
    
    // Multi-buffer rendering pipeline
    private let inFlightSemaphore: DispatchSemaphore
    private var currentBufferIndex = 0
    
    // The current viewport size
    private var viewportSize = CGSize()
    // The grid of sample points
    private lazy var gridPointsBuffer = MetalBuffer<Float2>(device: device,
                                                            array: makeGridPoints(),
                                                            index: kGridPoints.rawValue, options: [])
    
    // RGB buffer
    private lazy var rgbUniforms: RGBUniforms = {
        var uniforms = RGBUniforms()
        uniforms.radius = rgbRadius
        uniforms.viewToCamera.copy(from: viewToCamera)
        uniforms.viewRatio = Float(viewportSize.width / viewportSize.height)
        return uniforms
    }()
    private var rgbUniformsBuffers = [MetalBuffer<RGBUniforms>]()
    // Point Cloud buffer
    private lazy var pointCloudUniforms: PointCloudUniforms = {
        var uniforms = PointCloudUniforms()
        uniforms.maxPoints = Int32(maxPoints)
        uniforms.confidenceThreshold = Int32(2)
        uniforms.particleSize = particleSize
        uniforms.cameraResolution = cameraResolution
        return uniforms
    }()
    private var pointCloudUniformsBuffers = [MetalBuffer<PointCloudUniforms>]()
    // Particles buffer
    private var particlesBuffer: MetalBuffer<ParticleUniforms>
    private var currentPointIndex = 0
    var currentPointCount = 0
    
    // Camera data
    private var sampleFrame: ARFrame { session.currentFrame! }
    private lazy var cameraResolution = Float2(Float(sampleFrame.camera.imageResolution.width), Float(sampleFrame.camera.imageResolution.height))
    private lazy var viewToCamera = sampleFrame.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
    private lazy var lastCameraTransform = sampleFrame.camera.transform
    
    // interfaces
    var rgbRadius: Float = 0 {
        didSet {
            // apply the change for the shader
            rgbUniforms.radius = rgbRadius
        }
    }
    
    //init(session: ARSession, metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider) {
    init(session: ARSession, metalDevice device: MTLDevice, mtl_library: MTLLibrary, sceneView: ARSCNView, gridSize: Int) {
        self.session = session
        self.device = device
        self.sceneView = sceneView
        
        //adjust
        gridSizeX = gridSize
        gridSizeY = gridSize
        gridSizeZ = gridSize
        
        boundary_points = [Float](repeating: 0.0, count: 4)
        gridArray = [Grid].init(repeating: Grid(pointCount: 0, occ: false, fixed: false, position: simd_float3(x: 0.0, y:0.0, z:0.0)), count: gridSizeX*gridSizeY*gridSizeZ)
        boolGrid = [Bool].init(repeating: false, count: gridSizeX*gridSizeY*gridSizeZ)
        
        library = mtl_library
        commandQueue = sceneView.commandQueue!
        
        // initialize our buffers
        for _ in 0 ..< maxInFlightBuffers {
            rgbUniformsBuffers.append(.init(device: device, count: 1, index: 0))
            pointCloudUniformsBuffers.append(.init(device: device, count: 1, index: kPointCloudUniforms.rawValue))
        }
        particlesBuffer = .init(device: device, count: maxPoints, index: kParticleUniforms.rawValue)
        
        // rbg does not need to read/write depth
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!
        
        // setup depth test for point cloud
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        //depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.depthCompareFunction = .greaterEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        inFlightSemaphore = DispatchSemaphore(value: maxInFlightBuffers)
    }
    
    func convert3DIndex(x:Int, y:Int, z:Int) -> Int {
        let idx = (x*gridSizeY*gridSizeZ + y*gridSizeZ + z)
        return idx
    }
    
    // for occuapancy grid view in simViewer
    func eraseGrid(_ nodePos: simd_float3) {
        
        let rotPos = simd_float3(Float(cos(rotationValue)) * nodePos.x + Float(sin(rotationValue)) * nodePos.z,
                                 nodePos.y,
                                      -Float(sin(rotationValue)) * nodePos.x + Float(cos(rotationValue)) * nodePos.z)
        
        var ind_x = Int(Float(gridSizeX)*(rotPos.x - boundary_points[1])/gridLengthX)
        var ind_y = Int(Float(gridSizeY)*(rotPos.y - pc_min_y)/gridLengthY)
        var ind_z = Int(Float(gridSizeZ)*(rotPos.z - boundary_points[3])/gridLengthZ)
        
        if ind_x >= gridSizeX {
            ind_x = gridSizeX - 1
        }
        if ind_x < 0 {
            ind_x = 0
        }
        if ind_y >= gridSizeY {
            ind_y = gridSizeY - 1
        }
        if ind_y < 0 {
            ind_y = 0
        }
        if ind_z >= gridSizeZ {
            ind_z = gridSizeZ - 1
        }
        if ind_z < 0 {
            ind_z = 0
        }
        let idx = convert3DIndex(x: ind_x, y: ind_y, z: ind_z)
        gridArray[idx].fixed = true
        gridArray[idx].occ = false
        boolGrid[idx] = false
    }
    
    // for initializing occupancy grid
    func checkSideline() -> Bool{
        
        var P0 = boundary_points[0]; var P1 = boundary_points[1]
        var P2 = boundary_points[2]; var P3 = boundary_points[3]
        
        var temp_max_x : Float = 0.0
        var temp_min_x : Float = 0.0
        var temp_max_y : Float = 0.0
        var temp_min_y : Float = 0.0
        var temp_max_z : Float = 0.0
        var temp_min_z : Float = 0.0
        
        var max_x_index : Int = -1
        var min_x_index : Int = gridSizeX + 1
        var max_y_index : Int = -1
        var min_y_index : Int = gridSizeY + 1
        var max_z_index : Int = -1
        var min_z_index : Int = gridSizeZ + 1
        
        for i in 0..<currentPointIndex{
            let rotParticle = simd_float3(Float(cos(rotationValue)) * particlesBuffer[i].position.x + Float(sin(rotationValue)) * particlesBuffer[i].position.z,
                                          particlesBuffer[i].position.y,
                                          -Float(sin(rotationValue)) * particlesBuffer[i].position.x + Float(cos(rotationValue)) * particlesBuffer[i].position.z)
            
            if pc_max_y <= particlesBuffer[i].position.y{
                pc_max_y = particlesBuffer[i].position.y
            }
            if pc_min_y > particlesBuffer[i].position.y{
                pc_min_y = particlesBuffer[i].position.y
            }
            if P0 <= rotParticle.x{
                P0 = rotParticle.x
                //P0.z = particlesBuffer[i].position.z
            }
            if P1 > rotParticle.x{
                P1 = rotParticle.x
                //P1.z = particlesBuffer[i].position.z
            }
            if P2 <= rotParticle.z{
                //P2.x = particlesBuffer[i].position.x
                P2 = rotParticle.z
            }
            if P3 > rotParticle.z{
                //P3.x = particlesBuffer[i].position.x
                P3 = rotParticle.z
            }
            
            gridLengthX = P0 - P1
            gridLengthY = pc_max_y - pc_min_y
            gridLengthZ = P2 - P3
        }

        gridSizeX = Int(gridLengthX/0.1)
        gridSizeY = Int(gridLengthY/0.1)
        gridSizeZ = Int(gridLengthZ/0.1)
        
        for i in 0 ..< currentPointIndex{
            let x = Float(cos(rotationValue)) * particlesBuffer[i].position.x + Float(sin(rotationValue)) * particlesBuffer[i].position.z
            let y = particlesBuffer[i].position.y
            let z = -Float(sin(rotationValue)) * particlesBuffer[i].position.x + Float(cos(rotationValue)) * particlesBuffer[i].position.z
          
            let a = Int(Float(gridSizeX)*(x - P1)/gridLengthX)
            let b = Int(Float(gridSizeY)*(y - pc_min_y)/gridLengthY)
            let c = Int(Float(gridSizeZ)*(z - P3)/gridLengthZ)
            
            if a >= 0 && a < gridSizeX && b >= 0 && b < gridSizeY && c >= 0 && c < gridSizeZ{
                let idx = convert3DIndex(x: a, y: b, z: c)
                gridArray[idx].pointCount += 1
                if gridArray[idx].pointCount >= pointThresh {
                    gridArray[idx].occ = true
                    boolGrid[idx] = true
                    
                    if a > max_x_index{
                        max_x_index = a
                        temp_max_x = x
                    }
                    if a < min_x_index{
                        min_x_index = a
                        temp_min_x = x
                    }
                    if b > max_y_index{
                        max_y_index = b
                        temp_max_y = y
                    }
                    if b < min_y_index{
                        min_y_index = b
                        temp_min_y = y
                    }
                    if c > max_z_index{
                        max_z_index = c
                        temp_max_z = z
                    }
                    if c < min_z_index{
                        min_z_index = c
                        temp_min_z = z
                    }
                }
            }
        }

        P0 = temp_max_x
        P1 = temp_min_x
        
        pc_max_y = temp_max_y
        pc_min_y = temp_min_y
        
        P2 = temp_max_z
        P3 = temp_min_z
        
        // set corners
        if cornerArray.count == 4 {  //add //add //add
            var rotCornersX:[Float] = []
            var rotCornersZ:[Float] = []
            
            for i in 0 ..< cornerArray.count {
                rotCornersX.append(Float(cos(rotationValue)) * cornerArray[i].x + Float(sin(rotationValue)) * cornerArray[i].z)
                rotCornersZ.append(-Float(sin(rotationValue)) * cornerArray[i].x + Float(cos(rotationValue)) * cornerArray[i].z)
            }
            
            P0 = 0
            P1 = 0
            P2 = 0
            P3 = 0
            for i in 0 ..< cornerArray.count {
                if P0 <= rotCornersX[i] {
                    P0 = rotCornersX[i]
                }
                if P1 >= rotCornersX[i] {
                    P1 = rotCornersX[i]
                }
                if P2 <= rotCornersZ[i] {
                    P2 = rotCornersZ[i]
                }
                if P3 >= rotCornersZ[i] {
                    P3 = rotCornersZ[i]
                }
            }
        }
        
        
        if imagePos != simd_float3(0,0,0) {
            let imageX = Float(cos(rotationValue)) * imagePos.x + Float(sin(rotationValue)) * imagePos.z
            let imageY = imagePos.y
            let imageZ = -Float(sin(rotationValue)) * imagePos.x + Float(cos(rotationValue)) * imagePos.z
            P3 = imageZ
            pxLen = abs(P0 - imageX)
            mxLen = abs(P1 - imageX)
            pyLen = abs(pc_max_y - imageY)
            myLen = abs(pc_min_y - imageY)
        }
        
        gridLengthX = P0 - P1
        gridLengthY = pc_max_y - pc_min_y
        gridLengthZ = P2 - P3
        
        gridSizeX = Int(gridLengthX/0.1)
        gridSizeY = Int(gridLengthY/0.1)
        gridSizeZ = Int(gridLengthZ/0.1)
        
        if (gridSizeX <= 0 || gridSizeY <= 0 || gridSizeZ <= 0) {
            
            return false
        }
        
        gridArray = [Grid].init(repeating: Grid(pointCount: 0, occ: false, fixed: false, position: simd_float3(x: 0.0, y:0.0, z:0.0)), count: gridSizeX*gridSizeY*gridSizeZ)
        boolGrid = [Bool].init(repeating: false, count: gridSizeX*gridSizeY*gridSizeZ)
        
        for i in 0 ..< currentPointIndex{
            let x = Float(cos(rotationValue)) * particlesBuffer[i].position.x + Float(sin(rotationValue)) * particlesBuffer[i].position.z
            let y = particlesBuffer[i].position.y
            let z = -Float(sin(rotationValue)) * particlesBuffer[i].position.x + Float(cos(rotationValue)) * particlesBuffer[i].position.z
        
            let a = Int(Float(gridSizeX)*(x - P1)/gridLengthX)
            let b = Int(Float(gridSizeY)*(y - pc_min_y)/gridLengthY)
            let c = Int(Float(gridSizeZ)*(z - P3)/gridLengthZ)
                    
            if a >= 0 && a < gridSizeX && b >= 0 && b < gridSizeY && c >= 0 && c < gridSizeZ{
                let idx = convert3DIndex(x: a, y: b, z: c)
                gridArray[idx].pointCount += 1
                if gridArray[idx].pointCount >= pointThresh {
                    gridArray[idx].occ = true
                    boolGrid[idx] = true
                }
            }
        }
        
        let tempA = Int(Float(gridSizeX)*(0 - P1)/gridLengthX)
        let tempB = Int(Float(gridSizeY)*(0 - pc_min_y)/gridLengthY)
        let tempC = Int(Float(gridSizeZ)*(0 - P3)/gridLengthZ)
        let tempidx = convert3DIndex(x: tempA, y: tempB, z: tempC)
        gridArray[tempidx].occ = false
        boolGrid[tempidx] = false
        
        for i in 0 ..< gridSizeX {
            for j in 0 ..< gridSizeY {
                for k in 0 ..< gridSizeZ {
                    let idx = convert3DIndex(x: i, y: j, z: k)
                    let xSize = gridLengthX / Float(gridSizeX) * Float(i)
                    let ySize = gridLengthY / Float(gridSizeY) * Float(j)
                    let zSize = gridLengthZ / Float(gridSizeZ) * Float(k)
                    
                    gridArray[idx].position.x = Float(P1 + (gridLengthX / (2 * Float(gridSizeX))) + xSize)
                    gridArray[idx].position.y = Float(pc_min_y + (gridLengthY / (2 * Float(gridSizeY))) + ySize)
                    gridArray[idx].position.z = Float(P3 + (gridLengthZ / (2 * Float(gridSizeZ))) + zSize)
                }
            }
        }
        
        boundary_points[0] = P0
        boundary_points[1] = P1
        boundary_points[2] = P2
        boundary_points[3] = P3
        gridCreated = true
        
        return true
    }
    
    func updateGrid() {
        if gridCreated {
            for i in currentPointIndex - gridPointsBuffer.count * 2 ..< currentPointIndex - gridPointsBuffer.count{
                let x = Float(cos(rotationValue)) * particlesBuffer[i].position.x + Float(sin(rotationValue)) * particlesBuffer[i].position.z
                let y = particlesBuffer[i].position.y
                let z = -Float(sin(rotationValue)) * particlesBuffer[i].position.x + Float(cos(rotationValue)) * particlesBuffer[i].position.z
                
                //calc world to index
                let a = Int(Float(gridSizeX)*(x - boundary_points[1])/gridLengthX)
                let b = Int(Float(gridSizeY)*(y - pc_min_y)/gridLengthY)
                let c = Int(Float(gridSizeZ)*(z - boundary_points[3])/gridLengthZ)
                
                if a >= 0 && a < gridSizeX && b >= 0 && b < gridSizeY && c >= 0 && c < gridSizeZ{
                    let idx = convert3DIndex(x: a, y: b, z: c)
                    gridArray[idx].pointCount += 1
                    if gridArray[idx].pointCount >= pointThresh && gridArray[idx].fixed == false{
                        gridArray[idx].occ = true
                        boolGrid[idx] = true
                    }
                }
            }
        }
    }
    
    func loadGrid(px:Float, mx:Float, py:Float, my:Float) {
        gridArray = [Grid].init(repeating: Grid(pointCount: 0, occ: false, fixed: false, position: simd_float3(x: 0.0, y:0.0, z:0.0)), count: gridSizeX*gridSizeY*gridSizeZ)
        
        print(boolGrid.count)
        print(gridSizeX*gridSizeY*gridSizeZ)
        
        let rotImg = simd_float3(Float(cos(rotationValue)) * imagePos.x + Float(sin(rotationValue)) * imagePos.z,
                                        imagePos.y,
                                      -Float(sin(rotationValue)) * imagePos.x + Float(cos(rotationValue)) * imagePos.z)
        boundary_points[0] = rotImg.x + px
        boundary_points[1] = rotImg.x - mx
        pc_max_y = rotImg.y + py
        pc_min_y = rotImg.y - my
        boundary_points[2] = rotImg.z + gridLengthZ
        boundary_points[3] = rotImg.z
        
        for i in 0 ..< gridSizeX {
            for j in 0 ..< gridSizeY {
                for k in 0 ..< gridSizeZ {
                    let idx = convert3DIndex(x: i, y: j, z: k)
                    let xSize = gridLengthX / Float(gridSizeX) * Float(i)
                    let ySize = gridLengthY / Float(gridSizeY) * Float(j)
                    let zSize = gridLengthZ / Float(gridSizeZ) * Float(k)
                    
                    gridArray[idx].position.x = Float(boundary_points[1] + (gridLengthX / (2 * Float(gridSizeX))) + xSize)
                    gridArray[idx].position.y = Float(pc_min_y + (gridLengthY / (2 * Float(gridSizeY))) + ySize)
                    gridArray[idx].position.z = Float(boundary_points[3] + (gridLengthZ / (2 * Float(gridSizeZ))) + zSize)
                }
            }
        }
                
        for i in 0 ..< boolGrid.count {
            if boolGrid[i] == true {
                gridArray[i].occ = true
            }
        }
        gridCreated = true
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
   
    private func updateCapturedImageTextures(frame: ARFrame) {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        let pixelBuffer = frame.capturedImage
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
            return
        }
        
        capturedImageTextureY = makeTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = makeTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
    }
    
    private func updateDepthTextures(frame: ARFrame) -> Bool {
        guard let depthMap = frame.sceneDepth?.depthMap,
            let confidenceMap = frame.sceneDepth?.confidenceMap else {
                return false
        }
        
        depthTexture = makeTexture(fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0)
        confidenceTexture = makeTexture(fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0)
        
        return true
    }
    
    func update(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder) {
        // frame dependent info
        let camera = frame.camera
        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        let viewMatrix = camera.viewMatrix(for: orientation)
        let viewMatrixInversed = viewMatrix.inverse
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0.0)
    
        pointCloudUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
        pointCloudUniforms.localToWorld = viewMatrixInversed * rotateToARCamera
        pointCloudUniforms.cameraIntrinsicsInversed = cameraIntrinsicsInversed
        
        if shouldAccumulate(frame: frame), updateDepthTextures(frame: frame), !sessionPaused{
            accumulatePoints(frame: frame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        }
    }
    
    func draw() {
        guard let currentFrame = session.currentFrame,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = sceneView.currentRenderCommandEncoder else {
                return
        }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        commandBuffer.addCompletedHandler { [weak self] commandBuffer in
            if let self = self {
                self.inFlightSemaphore.signal()
            }
        }
        
        // update frame data
        updateCapturedImageTextures(frame: currentFrame)
        update(frame: currentFrame, commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        
        // handle buffer rotating
        currentBufferIndex = (currentBufferIndex + 1) % maxInFlightBuffers
        pointCloudUniformsBuffers[currentBufferIndex][0] = pointCloudUniforms
        
        if renderRGB {
            var retainingTextures = [capturedImageTextureY, capturedImageTextureCbCr]
            commandBuffer.addCompletedHandler { buffer in
                retainingTextures.removeAll()
            }
            rgbUniformsBuffers[currentBufferIndex][0] = rgbUniforms
            renderEncoder.setDepthStencilState(relaxedStencilState)
            renderEncoder.setRenderPipelineState(rgbPipelineState)
            renderEncoder.setVertexBuffer(rgbUniformsBuffers[currentBufferIndex])
            renderEncoder.setFragmentBuffer(rgbUniformsBuffers[currentBufferIndex])
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        else if viewPaused {
            return
        }
        else {
            // render particles
            renderEncoder.setDepthStencilState(depthStencilState)
            renderEncoder.setRenderPipelineState(particlePipelineState)
            renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
            renderEncoder.setVertexBuffer(particlesBuffer)
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: currentPointCount)
            commandBuffer.commit()
        }
    }
    
    private func shouldAccumulate(frame: ARFrame) -> Bool {
        //return true
        let cameraTransform = frame.camera.transform
        let shouldAccum = currentPointCount == 0
          || dot(cameraTransform.columns.2, lastCameraTransform.columns.2) <= cameraRotationThreshold
          || distance_squared(cameraTransform.columns.3, lastCameraTransform.columns.3) >= cameraTranslationThreshold
      
        return shouldAccum
    }
    
    private func accumulatePoints(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder) {
        pointCloudUniforms.pointCloudCurrentIndex = Int32(currentPointIndex)
        
        var retainingTextures = [capturedImageTextureY, capturedImageTextureCbCr, depthTexture, confidenceTexture]
        commandBuffer.addCompletedHandler { buffer in
            retainingTextures.removeAll()
        }
        
        renderEncoder.setDepthStencilState(relaxedStencilState)
        renderEncoder.setRenderPipelineState(unprojectPipelineState)
        renderEncoder.setVertexBuffer(pointCloudUniformsBuffers[currentBufferIndex])
        renderEncoder.setVertexBuffer(particlesBuffer)
        renderEncoder.setVertexBuffer(gridPointsBuffer)
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureY!), index: Int(kTextureY.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr!), index: Int(kTextureCbCr.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(depthTexture!), index: Int(kTextureDepth.rawValue))
        renderEncoder.setVertexTexture(CVMetalTextureGetTexture(confidenceTexture!), index: Int(kTextureConfidence.rawValue))
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: gridPointsBuffer.count)
        
        if gridCreated {
            updateGrid()
        }
        currentPointIndex = (currentPointIndex + gridPointsBuffer.count) % maxPoints
        currentPointCount = min(currentPointCount + gridPointsBuffer.count, maxPoints)
      
        lastCameraTransform = frame.camera.transform
    }
}

// MARK: - Metal Helpers

private extension PCRenderer {
    func makeUnprojectionPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "unprojectVertex") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.isRasterizationEnabled = false
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeRGBPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "rgbVertex"),
            let fragmentFunction = library.makeFunction(name: "rgbFragment") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeParticlePipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "particleVertex"),
            let fragmentFunction = library.makeFunction(name: "particleFragment") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        //descriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    /// Makes sample points on camera image, also precompute the anchor point for animation
    func makeGridPoints() -> [Float2] {
        let gridArea = cameraResolution.x * cameraResolution.y
        let spacing = sqrt(gridArea / Float(numGridPoints))
        let deltaX = Int(round(cameraResolution.x / spacing))
        let deltaY = Int(round(cameraResolution.y / spacing))
        
        var points = [Float2]()
        for gridY in 0 ..< deltaY {
            let alternatingOffsetX = Float(gridY % 2) * spacing / 2
            for gridX in 0 ..< deltaX {
                let cameraPoint = Float2(alternatingOffsetX + (Float(gridX) + 0.5) * spacing, (Float(gridY) + 0.5) * spacing)
                
                points.append(cameraPoint)
            }
        }
        
        return points
    }
    
    func makeTextureCache() -> CVMetalTextureCache {
        // Create captured image texture cache
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        
        return cache
    }
    
    func makeTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }
    
    static func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .landscapeLeft:
            return 180
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return -90
        default:
            return 0
        }
    }
    
    static func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        // flip to ARKit Camera's coordinate
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
}
