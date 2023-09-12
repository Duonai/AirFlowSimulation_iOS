//
//  MyRenderer.swift
//  SceneDepthPointCloud
//
//  Created by Donghan Kim on 2022/02/08.
//  Copyright © 2022 Apple. All rights reserved.
//

import ARKit
import SceneKit
import Metal
import MetalKit
import simd
import SceneKit.ModelIO

class SimulationRenderer {
    
    var session: ARSession
    var device: MTLDevice!
    var sceneView: ARSCNView!
    var mtl_library: MTLLibrary!
    var textureCache: CVMetalTextureCache!
    var globalLightingCubeMap: MTLTexture!
    let maxInFlightBuffers = 1
    var bufferNode: [primVert] = []
    
    // simulation state variables
    var modelAC: AirConditioner!
    var globalLight: lightUniform!
    var acInstalled: Bool = false
    var currentVisualization: String = "RGB"
    var complete_occlude: Bool = false
    var volume_occlude: Bool = true
    
    var acAngle: Int = 1
    
    // device screen variables
    let orientation = UIInterfaceOrientation.landscapeRight
    var viewPortSize: CGSize!
    var rotateToARCamera: matrix_float4x4!
    var cameraUniform: CameraUniforms!
    
    // rgb image rendering variables
    var rgbPipeline: MTLRenderPipelineState!
    var relaxedStencilState: MTLDepthStencilState!
    var rgbUniforms: RGBUniforms!
    var rgbUniformsBuffers = [MetalBuffer<RGBUniforms>]()
    var currentBufferIndex = 0
    
    // obj model rendering variables
    var instancedPipeline: MTLRenderPipelineState!
    var objPipeline: MTLRenderPipelineState!
    var primitivePipeline: MTLRenderPipelineState!
    var primitiveVolumePipeline: MTLRenderPipelineState!
    var particlePipeline: MTLRenderPipelineState!
    var objDepthStencilState: MTLDepthStencilState!
    var objVertexDescriptor: MDLVertexDescriptor!
    var objBufferAllocator: MTKMeshBufferAllocator!
    var textureLoader: MTKTextureLoader!
    var textureSamplerState: MTLSamplerState!
    
    // simulation variables
    var comms: Communication!
    var gpuCompute: Compute!
    var velocityData: [Float] = []
    var temperatureData: [Float] = []
    var eye: simd_float3!
    var boundary_points:[Float]!
    var pc_max_y: Float = 0
    var pc_min_y: Float = 0
    var gridArray:[Grid]!
    var gridSizeX:Int = 0
    var gridSizeY:Int = 0
    var gridSizeZ:Int = 0
    var gd = gridUniform()
    var boolGrid:[Bool]!
    var mutex_lock = NSLock()
    var displayLink: CADisplayLink?
    
    // vector visualization variables
    var maxArrow: Int = 3000
    var arrowInstance: ModelInstace!
    var arrowNodeArr: [objNode] = []
    var arrowCreated: Bool = false
    var ArrowTimer:Int = 0
    
    // volume visualization variables
    var volumePlane: Model!
    var nearNum: Float = 0.75
    var plane_nums: Int = 5
    //var planel_arr: [planel] = []
    var planeUniforms = planeUniform()
    //var planeNodeArr: [primVert] = []
    
    // particle visualization
    var maxParticle: Int = 100_000_000
    var Particle: Model!
    var particleNodeArr: [primVert] = []
    var particleCreated: Bool = false
    var particleDistance: Float = 0.3
    
    //striped streamline//
    //line visualization
    //var lineArray:[SCNNode] = []
    var lineModel: Model!
    
    var lineTimer:Float = 0

    var streamlineStarted:Bool = false

    //Vector3[] seeds = new Vector3[90];
    var lineParticleSpeed:Float = 0.1
    var lineCnt:Int = 0
    public var maxLineCnt:Int = 90
    public var maxLineStLen:Int = 180

    public var lineLength:Int = 6
    public var lineSpeed:Float = 45
    public var lineWidthScale:Float = 0.005
    public var lineColor:simd_float4 = simd_float4(1, 1, 1, 1)
    
    private let maxLineVerticesInBuffer:Int = 40000
    private var lineVertices:[simd_float3]! //new Vector3[_maxVerticesInBuffer]
    private var lineVerticesCount:Int = 0
    private var lineVerticesIndex:Int = 0
    private var lineIndices:[UInt32]! //new int[6*_maxVerticesInBuffer]
    private var lineVerticesColors:[simd_float4]! //new Color32[_maxVerticesInBuffer]

    var streamlines:[[simd_float3]]!
    var lineOcclude:[[Bool]]! //new Vector3[_maxVerticesInBuffer]

    //const bool use_gpu = false;
    //var verticesBuffer:[Float] = []
    //Simulation.vel_temp_format[] outputBuffer;
    
    //surface visualization//
    var surfaceModel: Model!
    
    //advection variables
    var particleSpeed:Float = 0.0075
    var cutOffVelocity:Float = 1e-05
    
    //mesh dimension
    var maxNodeCnt:Int = 70
    var maxStLen:Int = 300
    var stLen:Int = 0
    
    //surface texturing
    var animationSpeed:Float = 100
    var animationThickness:Int = 2
    var textureColor:simd_float4 = simd_float4(0.1557, 0.701, 0.9433, 1)

    //surface refinement parameters
    let minWidth:Float = 0.004
    let maxWidth:Float = 0.04
    let alpha:Float = 2.0
    let beta:Float = 1.3
    let delta:Float = 0.8
    let zeta:Float = 0.8
    let gamma:Float = 0.02

    private let maxVerticesInBuffer:Int = 300000
    private var surfaceVertices:[simd_float3]! //new Vector3[_maxVerticesInBuffer]
    private var surfaceVerticesCount:Int = 0
    private var surfaceVerticesIndex:Int = 0
    private var surfaceIndices:[UInt32]! //new int[6*_maxVerticesInBuffer]
    private var surfaceColors:[simd_float4]! //new Color32[_maxVerticesInBuffer]

    //surface struct
    struct surfaceGroup
    {
        public var gridPos:[[simd_float3]]!
        public var occlude:[[Bool]]!
        public var nextIdx:[[Int]]!
        public var areaZero:[Float]!
        public var pred:[[Int]]!
        public var succ:[[Int]]!
        public var valid:[[Bool]]!
        public var opacity:[[Float]]!
    }
    var surfaceCnt:Int = 4
    var surfaces:[surfaceGroup]! //new surface[surfaceCnt]
    
    //simaulation variables
    private var surfaceTimer:Float = 0
    private var surfaceStarted:Bool = false

    //gpu buffer
    let use_gpu:Bool = false
//    float[] verticesBuffer
//    Simulation.vel_temp_format[] outputBuffer

    //var Vcnt:Int = 0
    
    // occupancy grid visualization variables
    var maxGrid: Int = 1_000_000
    var boxNode: SCNNode!
    var gridInstance: ModelInstace!
    var gridNodeArr: [objNode] = []
    var gridNotReady = true
    
    // rotation
    var rotationValue:Float = 0.0
    var rotAxisX:simd_float3 = simd_float3(Float(cos(-0.0)), 0, Float(-sin(-0.0)))
    var rotAxisZ:simd_float3 = simd_float3(Float(sin(-0.0)), 0, Float(cos(-0.0)))
    
    // pinpoint
    var graph: Grapher!
    var pinNode: SCNNode!
    var pinNodeText: SCNNode!
    var cameraToPoint: Float = 0.0
    
    // timer
    var timeData: [Double] = []
    var renderData: [Double] = []
    
    init(scnview: ARSCNView, gridSize: Int, mtl_library: MTLLibrary, comms: Communication) {
        self.sceneView = scnview
        self.session = scnview.session
        self.device = scnview.device
        self.mtl_library = mtl_library
        
        self.gridSizeX = gridSize
        self.gridSizeY = gridSize
        self.gridSizeZ = gridSize
        
        self.gpuCompute = Compute()
        self.gpuCompute.create_pipelinestate(device: device, mtl_library: mtl_library)
        self.gpuCompute.createBuffer(device: scnview.device!)
        self.comms = comms
        
        //surface init
        self.surfaceVertices = [simd_float3](repeating: simd_float3(0,0,0), count: maxVerticesInBuffer)
        self.surfaceIndices = [UInt32](repeating: 0, count: 6 * maxVerticesInBuffer)
        self.surfaceColors = [simd_float4](repeating: simd_float4(0,0,0,0), count: maxVerticesInBuffer)
        self.surfaces = [surfaceGroup](repeating: surfaceGroup(
        gridPos: [[simd_float3]](repeating: Array(repeating: simd_float3(0,0,0), count: maxStLen), count: maxNodeCnt),
        occlude: [[Bool]](repeating: Array(repeating: false, count: maxStLen), count: maxNodeCnt),
        nextIdx: [[Int]](repeating: Array(repeating: 0, count: maxStLen), count: maxNodeCnt),
        areaZero: [Float](repeating: 0.0, count: maxNodeCnt),
        pred: [[Int]](repeating: Array(repeating: 0, count: maxStLen), count: maxNodeCnt),
        succ: [[Int]](repeating: Array(repeating: 0, count: maxStLen), count: maxNodeCnt),
        valid: [[Bool]](repeating: Array(repeating: false, count: maxStLen), count: maxNodeCnt),
        opacity: [[Float]](repeating: Array(repeating: 0.0, count: maxStLen), count: maxNodeCnt)),
                                       count: surfaceCnt)
        
        //line init
        self.streamlines = [[simd_float3]](repeating: Array(repeating: simd_float3(0,0,0), count: maxLineStLen), count: maxLineCnt)
        self.lineOcclude = [[Bool]](repeating: Array(repeating: false, count: maxLineStLen), count: maxLineCnt)
        self.lineVertices = [simd_float3](repeating: simd_float3(0,0,0), count: maxLineVerticesInBuffer)
        self.lineIndices = [UInt32](repeating: 0, count: 24 * maxLineVerticesInBuffer)
        self.lineVerticesColors = [simd_float4](repeating: simd_float4(0,0,0,0), count: maxLineVerticesInBuffer)
    }
                    
    func updateCamera(frame: ARFrame){
        let camera = frame.camera
        let intrinsic = camera.intrinsics
        let viewMatrix = camera.viewMatrix(for: orientation)
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewPortSize, zNear: 0.01, zFar: 0.0)
    
        var uniforms = CameraUniforms()
        uniforms.projectionMatrix = projectionMatrix
        uniforms.viewMatrix = viewMatrix
        uniforms.localToWorld = viewMatrix.inverse * rotateToARCamera
        uniforms.cameraIntrinsics = intrinsic
        cameraUniform = uniforms
        
        let viewMatInv = viewMatrix.transpose.inverse
        eye = simd_float3(viewMatInv[0,3], viewMatInv[1,3], viewMatInv[2,3])
        gd.eye = eye
    }
        
    func get_server_data(){
        mutex_lock.lock()
        velocityData = comms.getVelocity()
        temperatureData = comms.getTemperature()
        mutex_lock.unlock()
        
        gpuCompute.velocityData = velocityData
        gpuCompute.temperatureData = temperatureData
        gpuCompute.gridArray = gridArray
        gpuCompute.boundary_points = boundary_points
        gpuCompute.gd = gd
        gpuCompute.volume_occlude = volume_occlude
        gpuCompute.rotationValue = rotationValue
    }
        
    // MARK: - Vector Visualization
    
    func createArrowAnimation(x:Int, y:Int, z:Int) {
        
        let indicies = convert3DIndex(x, y, z)
        var velocity = simd_float3(velocityData[indicies.1], velocityData[indicies.1 + 1], velocityData[indicies.1 + 2])
        velocity = simd_float3(Float(cos(-rotationValue)) * velocity.x + Float(sin(-rotationValue)) * velocity.z,
                                velocity.y,
                                -Float(sin(-rotationValue)) * velocity.x + Float(cos(-rotationValue)) * velocity.z)
        
        var worldPos = gridArray[indicies.0].position
        worldPos = simd_float3(Float(cos(-rotationValue)) * worldPos.x + Float(sin(-rotationValue)) * worldPos.z,
                                worldPos.y,
                                -Float(sin(-rotationValue)) * worldPos.x + Float(cos(-rotationValue)) * worldPos.z)
        
        let position = simd_float3(worldPos.x, worldPos.y-0.01, worldPos.z)
        let theta = acos(velocity.y/(sqrt(pow(velocity.x, 2) + pow(velocity.y, 2) + pow(velocity.z, 2))))
        let qaxis = simd.normalize(simd_float3(velocity.z, 0.0, -1*velocity.x))
        let rotation = float4x4(simd_quatf(angle: theta, axis: qaxis))
        let scale = float4x4(scaling: simd_float3(0.035, 0.095, 0.035))
        
        let new_arrow = objNode(name: "arrow", position: position, rotation: rotation, scale: scale, color: simd_float4(0,0,0,0))
        arrowNodeArr.append(new_arrow)
    }
    
    func startArrowAnimation(){
        let rotACPosition = simd_float3(Float(cos(rotationValue)) * modelAC.currentPosition.x + Float(sin(rotationValue)) * modelAC.currentPosition.z,
                                        modelAC.currentPosition.y,
                                        -Float(sin(rotationValue)) * modelAC.currentPosition.x + Float(cos(rotationValue)) * modelAC.currentPosition.z)
        
        var ind_x = Int(Float(gridSizeX)*(rotACPosition.x - boundary_points[1])/gd.gridLengthX)
        var ind_y = Int(Float(gridSizeY)*(rotACPosition.y - pc_min_y)/gd.gridLengthY)
        var ind_z = Int(Float(gridSizeZ)*(rotACPosition.z - boundary_points[3])/gd.gridLengthZ)

        if ind_x >= gridSizeX{
            ind_x = gridSizeX - 1
        }
        else if ind_x < 0 {
            ind_x = 0
        }
        if ind_y >= gridSizeY{
            ind_y = gridSizeY - 1
        }
        else if ind_y < 0 {
            ind_x = 0
        }
        if ind_z >= gridSizeZ{
            ind_z = gridSizeZ - 1
        }
        else if ind_z < 0 {
            ind_z = 0
        }

        if modelAC.currentACModel == "ceiling" {
            ind_y -= 1
            for i in -2 ... 2 {
                if ind_x + i > -1 && ind_x + i < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z-4 > -1 && ind_z-4 < gridSizeZ{
                    createArrowAnimation(x: ind_x + i, y: ind_y, z: ind_z-4)
                }
            }
            for i in -2 ... 2 {
                if ind_x + i > -1 && ind_x + i < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+4 > -1 && ind_z+4 < gridSizeZ{
                    createArrowAnimation(x: ind_x + i, y: ind_y, z: ind_z+4)
                }
            }
            for i in -2 ... 2 {
                if ind_x-4 > -1 && ind_x-4 < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                    createArrowAnimation(x: ind_x-4, y: ind_y, z: ind_z + i)
                }
            }
            for i in -2 ... 2 {
                if ind_x+4 > -1 && ind_x+4 < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                    createArrowAnimation(x: ind_x+4, y: ind_y, z: ind_z + i)
                }
            }
        }
        
        else if modelAC.currentACModel == "wall"{  //add //add //add //add
            ind_y -= 1
            if modelAC.acOrientation == 4{ //"plus_x"
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x-1 > -1 && ind_x-1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createArrowAnimation(x: ind_x, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 0 { //"minus_x"
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x+1 > -1 && ind_x+1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createArrowAnimation(x: ind_x, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 2 { //"plus_z" {
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z-1 > -1 && ind_z-1 < gridSizeZ{
                            createArrowAnimation(x: ind_x+i, y: ind_y+j, z: ind_z)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 6 { //"minus_z" {
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+1 > -1 && ind_z+1 < gridSizeZ{
                            createArrowAnimation(x: ind_x+i, y: ind_y+j, z: ind_z)
                        }
                    }
                }
            }
        } //add //add //add //add //add
        
        else if modelAC.currentACModel == "stand"{
            ind_y += 16
            if modelAC.acOrientation == 4 { //"plus_x" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x+1 > -1 && ind_x+1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createArrowAnimation(x: ind_x+1, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 0 { //"minus_x" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x-1 > -1 && ind_x-1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createArrowAnimation(x: ind_x-1, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 2 { //"plus_z" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+1 > -1 && ind_z+1 < gridSizeZ{
                            createArrowAnimation(x: ind_x+i, y: ind_y+j, z: ind_z+1)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 6 { //"minus_z" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z-1 > -1 && ind_z-1 < gridSizeZ{
                            createArrowAnimation(x: ind_x+i, y: ind_y+j, z: ind_z-1)
                        }
                    }
                }
            }
        }
        else if modelAC.currentACModel == "tower"{
            for i in 7 ... 13 {
                switch modelAC.acOrientation {
                case 0:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x, y: ind_y+i, z: ind_z-2)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x, y: ind_y+i, z: ind_z+1)
                    }
                case 1:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x-1, y: ind_y+i, z: ind_z-1)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x+1, y: ind_y+i, z: ind_z+1)
                    }
                case 2:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x-2, y: ind_y+i, z: ind_z)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x+1, y: ind_y+i, z: ind_z)
                    }
                case 3:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x-1, y: ind_y+i, z: ind_z+1)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x+1, y: ind_y+i, z: ind_z-1)
                    }
                case 4:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x, y: ind_y+i, z: ind_z+2)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x, y: ind_y+i, z: ind_z-1)
                    }
                case 5:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x+1, y: ind_y+i, z: ind_z+1)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x-1, y: ind_y+i, z: ind_z-1)
                    }
                case 6:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x+2, y: ind_y+i, z: ind_z)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x-1, y: ind_y+i, z: ind_z)
                    }
                case 7:
                    if (acAngle != 6){
                        createArrowAnimation(x: ind_x+1, y: ind_y+i, z: ind_z-1)
                    }
                    if (acAngle != 7){
                        createArrowAnimation(x: ind_x-1, y: ind_y+i, z: ind_z+1)
                    }
                default:
                    print("Error, wrong AC direction")
                }
            }
            
            for i in stride(from: 0, to: Float.pi*2, by: Float.pi/6) {
                let indicies = convert3DIndex(ind_x, ind_y, ind_z)
                var velocity = simd_float3(velocityData[indicies.1], velocityData[indicies.1 + 1], velocityData[indicies.1 + 2])
                velocity = simd_float3(Float(cos(-rotationValue)) * velocity.x + Float(sin(-rotationValue)) * velocity.z,
                                        velocity.y,
                                        -Float(sin(-rotationValue)) * velocity.x + Float(cos(-rotationValue)) * velocity.z)
                
                var worldPos = gridArray[indicies.0].position
                
                var xzVec1 = simd_float3(1,0,1)
                xzVec1 = simd.normalize(xzVec1)
                
                var xzVec2 = simd_float3(1,0,-1)
                xzVec2 = simd.normalize(xzVec2)
                
                switch modelAC.acOrientation {
                case 0:
                    worldPos = simd_float3(worldPos.x+0.05,
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z-0.05+0.15*cos(i))
                case 1:
                    worldPos = simd_float3(worldPos.x,
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z) - (0.15*cos(i))*xzVec1
                case 2:
                    worldPos = simd_float3(worldPos.x-0.05+0.15*cos(i),
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z-0.05)
                case 3:
                    worldPos = simd_float3(worldPos.x,
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z) - (0.15*cos(i))*xzVec2
                case 4:
                    worldPos = simd_float3(worldPos.x-0.05,
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z+0.05+0.15*cos(i))
                case 5:
                    worldPos = simd_float3(worldPos.x,
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z) + (0.15*cos(i))*xzVec1
                case 6:
                    worldPos = simd_float3(worldPos.x+0.05+0.15*cos(i),
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z+0.05)
                case 7:
                    worldPos = simd_float3(worldPos.x,
                                           worldPos.y+1.67+0.15*sin(i),
                                           worldPos.z) + (0.15*cos(i))*xzVec2
                default:
                    print("Error, wrong AC direction")
                }
                
                worldPos = simd_float3(Float(cos(-rotationValue)) * worldPos.x + Float(sin(-rotationValue)) * worldPos.z,
                                        worldPos.y,
                                        -Float(sin(-rotationValue)) * worldPos.x + Float(cos(-rotationValue)) * worldPos.z)
                
                let position = simd_float3(worldPos.x, worldPos.y, worldPos.z)
                let theta = acos(velocity.y/(sqrt(pow(velocity.x, 2) + pow(velocity.y, 2) + pow(velocity.z, 2))))
                let qaxis = simd.normalize(simd_float3(velocity.z, 0.0, -1*velocity.x))
                let rotation = float4x4(simd_quatf(angle: theta, axis: qaxis))
                let scale = float4x4(scaling: simd_float3(0.035, 0.095, 0.035))
                
                let new_arrow = objNode(name: "arrow", position: position, rotation: rotation, scale: scale, color: simd_float4(0,0,0,0))
                arrowNodeArr.append(new_arrow)
            }
        }
        
        arrowCreated = true
    }
    
    func updateArrow(currentFrame: ARFrame, arrow_speed: Float) {
        if arrowCreated {
            ArrowTimer += 1
            if ArrowTimer >= 28 {
                startArrowAnimation()
                ArrowTimer = 0
            }
            var removeArray:[Int] = []
            if arrowNodeArr.count > 0 {
                if arrowNodeArr.count >= maxArrow {
                    for i in 0 ..< 20 {
                        removeArray.append(i)
                    }
                }
            }
            
            var arrowVerticies: [simd_float3] = []
            for i in 0..<arrowNodeArr.count {
                arrowVerticies.append(arrowNodeArr[i].position)
            }
            
            gpuCompute.updateBuffers()
            let interpolatedValues = gpuCompute.gpu_interpolate(device: device, commandQueue: sceneView.commandQueue!, verticies: arrowVerticies)
    
            for i in 0 ..< arrowVerticies.count {
                let newTemp = interpolatedValues.0[i]
                let newDirection = interpolatedValues.1[i]
                let velocity = sqrt(pow(newDirection.x, 2) + pow(newDirection.y, 2) + pow(newDirection.z, 2))
                
                if (velocity < 0.022 || Float(1.0 - min(newTemp.x, 1.0)) > 0.85) && !removeArray.contains(i) {
                    removeArray.append(i)
                }
                
                let largeStep:Float = 0.16
                let smallStep:Float = 0.09
                
                var rotFlag:Bool = false
                let largePos = arrowNodeArr[i].position + newDirection * largeStep
                let rotPositionLarge = simd_float3(Float(cos(rotationValue)) * largePos.x + Float(sin(rotationValue)) * largePos.z,
                                                   largePos.y,
                                                -Float(sin(rotationValue)) * largePos.x + Float(cos(rotationValue)) * largePos.z)
                
                if rotPositionLarge.x <= boundary_points[0] && rotPositionLarge.x >= boundary_points[1] &&
                    rotPositionLarge.y <= gd.pc_max_y && rotPositionLarge.y >= gd.pc_min_y &&
                    rotPositionLarge.z <= boundary_points[2] && rotPositionLarge.z >= boundary_points[3]{
                    arrowNodeArr[i].position.x += newDirection.x * largeStep
                    arrowNodeArr[i].position.y += newDirection.y * largeStep
                    arrowNodeArr[i].position.z += newDirection.z * largeStep
                }
                else {
                    arrowNodeArr[i].position.x += newDirection.x * smallStep
                    arrowNodeArr[i].position.y += newDirection.y * smallStep
                    arrowNodeArr[i].position.z += newDirection.z * smallStep
                }
                
                let rotPositionX = Float(cos(rotationValue)) * Float(arrowNodeArr[i].position.x) + Float(sin(rotationValue)) *
                                    Float(arrowNodeArr[i].position.z)
                let rotPositionY = Float(arrowNodeArr[i].position.y)
                let rotPositionZ = -Float(sin(rotationValue)) * Float(arrowNodeArr[i].position.x) +
                                              Float(cos(rotationValue)) * Float(arrowNodeArr[i].position.z)
                
                var rotPosition = simd_float3(rotPositionX, rotPositionY, rotPositionZ)
                
                if rotPosition.x > gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x{
                    rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x - 0.05
                    rotFlag = true
                }
                if rotPosition.x < gridArray[convert3DIndex(0, 0, 0).0].position.x{
                    rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x + 0.05
                    rotFlag = true
                }
                if arrowNodeArr[i].position.y > gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y{
                    arrowNodeArr[i].position.y = gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y - 0.05
                }
                if arrowNodeArr[i].position.y < gridArray[convert3DIndex(0, 0, 0).0].position.y{
                    arrowNodeArr[i].position.y = gridArray[convert3DIndex(0, 0, 0).0].position.y + 0.05
                }
                if rotPosition.z > gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z{
                    rotPosition.z = gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z - 0.05
                    rotFlag = true
                }
                if rotPosition.z < gridArray[convert3DIndex(0, 0, 0).0].position.z{
                    rotPosition.z = gridArray[convert3DIndex(0, 0, 0).0].position.z + 0.05
                    rotFlag = true
                }
                
                if rotFlag {
                    arrowNodeArr[i].position = simd_float3(Float(cos(-rotationValue)) * rotPosition.x + Float(sin(-rotationValue)) * rotPosition.z,
                                                              rotPosition.y,
                                                           -Float(sin(-rotationValue)) * rotPosition.x + Float(cos(-rotationValue)) * rotPosition.z)
                    rotFlag = false
                }
                
                var newColor = getTemperatureColor(interpolated_temp: newTemp.x)
                if newTemp.y == 0.0 {
                    if !complete_occlude {
                        newColor.w = 0.7
                    }
                    else {
                        newColor.w = 0.0
                    }
                }
                else {
                    newColor.w = 1.0
                }
                
//                if newColor.x == 1.0 {
//                    removeArray.append(i)
//                }
                
                arrowNodeArr[i].color = newColor
                let theta = acos(newDirection.y/(sqrt(pow(newDirection.x, 2) + pow(newDirection.y, 2) + pow(newDirection.z, 2))))
                let qaxis = simd.normalize(simd_float3(newDirection.z, 0.0, -1*newDirection.x))
                let rotation = float4x4(simd_quatf(angle: theta, axis: qaxis))
                arrowNodeArr[i].rotation = rotation
            }
            removeArray.sort()
            for i in 0..<removeArray.count { //add //add //add //add
                if removeArray[i] - i < arrowNodeArr.count {
                    arrowNodeArr.remove(at: removeArray[i] - i)
                }
            } //add //add //add //add
        }
    }
    
    // MARK: - Volume Visualization
    
    func updatePlaneLocation() {
        guard let currentFrame = sceneView.session.currentFrame else {
            print("Could not get current frame AR Session...")
            return
        }
        let camera = currentFrame.camera
        let u_spacing = nearNum*0.8; let v_spacing = nearNum*0.6; let at_spacing = 0.2

        // getting N and EYE
        let view_matrix = camera.viewMatrix(for: UIInterfaceOrientation.landscapeRight).transpose.inverse
        let u = simd_float3(view_matrix[0,0], view_matrix[1,0], view_matrix[2,0])*Float(u_spacing)
        let v = simd_float3(view_matrix[0,1], view_matrix[1,1], view_matrix[2,1])*Float(v_spacing)
        let n = simd_float3(view_matrix[0,2], view_matrix[1,2], view_matrix[2,2])
        eye = simd_float3(view_matrix[0,3], view_matrix[1,3], view_matrix[2,3])
        let At = -1*n*nearNum

        let point0:simd_float3 = eye + At - v - u
        let point1:simd_float3 = eye + At - v + u
        let point2:simd_float3 = eye + At + v - u
        let point3:simd_float3 = eye + At + v + u
        
        gd.eye = eye
        planeUniforms.AT = At*Float(at_spacing)
        planeUniforms.U = u
        planeUniforms.V = v
        planeUniforms.p0 = point0
        planeUniforms.p1 = point1
        planeUniforms.p2 = point2
        planeUniforms.p3 = point3
    }
    
    // MARK: - Particle Vane
    func createParticleVane(x:Int, y:Int, z:Int) {
        let indicies = convert3DIndex(x, y, z)
        var worldPos = gridArray[indicies.0].position
        worldPos = simd_float3(Float(cos(-rotationValue)) * worldPos.x + Float(sin(-rotationValue)) * worldPos.z,
                                worldPos.y,
                                -Float(sin(-rotationValue)) * worldPos.x + Float(cos(-rotationValue)) * worldPos.z)
        
//        let i:Int = 0
//        let j:Int = 0
//        let k:Int = 0
        for _ in 0 ..< 27 {
            let i:Float = Float.random(in: -2...2)
            let j:Float = Float.random(in: -2...2)
            let k:Float = Float.random(in: -2...2)
            if worldPos.x >= boundary_points[0] - Float(i) * 0.02 {  //add //add //add //add
                worldPos.x = boundary_points[0] - Float(i) * 0.02 - 0.01
            }
            if worldPos.x <= boundary_points[1] - Float(i) * 0.02  {
                worldPos.x = boundary_points[1] - Float(i) * 0.02 + 0.01
            }
            if worldPos.y >= pc_max_y - Float(j) * 0.02 {
                worldPos.y = pc_max_y - Float(j) * 0.02 - 0.01
            }
            if worldPos.y <= pc_min_y - Float(j) * 0.02  {
                worldPos.y = pc_min_y - Float(j) * 0.02 + 0.01
            }
            if worldPos.z >= boundary_points[2] - Float(k) * 0.02 {
                worldPos.z = boundary_points[2] - Float(k) * 0.02 - 0.01
            }
            if worldPos.z <= boundary_points[3] - Float(k) * 0.02  {
                worldPos.z = boundary_points[3] - Float(k) * 0.02 + 0.01
            }
            let position = simd_float3(worldPos.x + Float(i) * 0.02, worldPos.y + Float(j) * 0.02, worldPos.z + Float(k) * 0.02)
            
            let new_particle = primVert(position: position, normal: simd_float3(0,0,0), color:simd_float4(0,0,0,0))
            particleNodeArr.append(new_particle)  //add //add //add //add //add
        }
    }
    
    func startParticleVane(){
        let rotACPosition = simd_float3(Float(cos(rotationValue)) * modelAC.currentPosition.x + Float(sin(rotationValue)) * modelAC.currentPosition.z,
                                        modelAC.currentPosition.y,
                                        -Float(sin(rotationValue)) * modelAC.currentPosition.x + Float(cos(rotationValue)) * modelAC.currentPosition.z)
        
        var ind_x = Int(Float(gridSizeX)*(rotACPosition.x - boundary_points[1])/gd.gridLengthX)
        var ind_y = Int(Float(gridSizeY)*(rotACPosition.y - pc_min_y)/gd.gridLengthY)
        var ind_z = Int(Float(gridSizeZ)*(rotACPosition.z - boundary_points[3])/gd.gridLengthZ)

        if ind_x >= gridSizeX{
            ind_x = gridSizeX - 1
        }
        else if ind_x < 0 {
            ind_x = 0
        }
        if ind_y >= gridSizeY{
            ind_y = gridSizeY - 1
        }
        else if ind_y < 0 {
            ind_x = 0
        }
        if ind_z >= gridSizeZ{
            ind_z = gridSizeZ - 1
        }
        else if ind_z < 0 {
            ind_z = 0
        }

        if modelAC.currentACModel == "ceiling" {
            ind_y -= 1
            for i in -2 ... 2 {
                if ind_x + i > -1 && ind_x + i < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z-4 > -1 && ind_z-4 < gridSizeZ{
                    createParticleVane(x: ind_x + i, y: ind_y, z: ind_z-4)
                }
            }
            for i in -2 ... 2 {
                if ind_x + i > -1 && ind_x + i < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+4 > -1 && ind_z+4 < gridSizeZ{
                    createParticleVane(x: ind_x + i, y: ind_y, z: ind_z+4)
                }
            }
            for i in -2 ... 2 {
                if ind_x-4 > -1 && ind_x-4 < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                    createParticleVane(x: ind_x-4, y: ind_y, z: ind_z + i)
                }
            }
            for i in -2 ... 2 {
                if ind_x+4 > -1 && ind_x+4 < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                    createParticleVane(x: ind_x+4, y: ind_y, z: ind_z + i)
                }
            }
            
            for i in -1 ... 1 {
                if ind_x + i > -1 && ind_x + i < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z-5 > -1 && ind_z-5 < gridSizeZ{
                    createParticleVane(x: ind_x + i, y: ind_y, z: ind_z-5)
                }
            }
            for i in -1 ... 1 {
                if ind_x + i > -1 && ind_x + i < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+5 > -1 && ind_z+5 < gridSizeZ{
                    createParticleVane(x: ind_x + i, y: ind_y, z: ind_z+5)
                }
            }
            for i in -1 ... 1 {
                if ind_x-5 > -1 && ind_x-5 < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                    createParticleVane(x: ind_x-5, y: ind_y, z: ind_z + i)
                }
            }
            for i in -1 ... 1 {
                if ind_x+5 > -1 && ind_x+5 < gridSizeX && ind_y > -1 && ind_y < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                    createParticleVane(x: ind_x+5, y: ind_y, z: ind_z + i)
                }
            }
        }
        else if modelAC.currentACModel == "wall"{  //add //add //add //add
            if modelAC.acOrientation == 4 { //"plus_x" {
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x-1 > -1 && ind_x-1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createParticleVane(x: ind_x, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 0 { //"minus_x" {
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x+1 > -1 && ind_x+1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createParticleVane(x: ind_x, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 2 { //"plus_z" {
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z-1 > -1 && ind_z-1 < gridSizeZ{
                            createParticleVane(x: ind_x+i, y: ind_y+j, z: ind_z)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 6 { //"minus_z" {
                for i in -3 ... 3 {
                    for j in -1 ... 0 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+1 > -1 && ind_z+1 < gridSizeZ{
                            createParticleVane(x: ind_x+i, y: ind_y+j, z: ind_z)
                        }
                    }
                }
            }
        }
        
        else if modelAC.currentACModel == "stand"{
            ind_y += 16
            if modelAC.acOrientation == 4 { //"plus_x" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x+1 > -1 && ind_x+1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createParticleVane(x: ind_x-1, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 0 { //"minus_x" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x-1 > -1 && ind_x-1 < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+i > -1 && ind_z+i < gridSizeZ{
                            createParticleVane(x: ind_x+1, y: ind_y+j, z: ind_z+i)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 2 { //"plus_z" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z+1 > -1 && ind_z+1 < gridSizeZ{
                            createParticleVane(x: ind_x+i, y: ind_y+j, z: ind_z+1)
                        }
                    }
                }
            }
            else if modelAC.acOrientation == 6 { //"minus_z" {
                for i in -2 ... 2 {
                    for j in -1 ... 1 {
                        if ind_x+i > -1 && ind_x+i < gridSizeX && ind_y+j > -1 && ind_y+j < gridSizeY && ind_z-1 > -1 && ind_z-1 < gridSizeZ{
                            createParticleVane(x: ind_x+i, y: ind_y+j, z: ind_z-1)
                        }
                    }
                }
            }
        }  //add //add //add //add //add //add //add
        
        else if modelAC.currentACModel == "tower"{
            for i in 7 ... 13 {
                switch modelAC.acOrientation {
                case 0:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x, y: ind_y+i, z: ind_z-2)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x, y: ind_y+i, z: ind_z+1)
                    }
                case 1:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x-1, y: ind_y+i, z: ind_z-1)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x+1, y: ind_y+i, z: ind_z+1)
                    }
                case 2:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x-2, y: ind_y+i, z: ind_z)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x+1, y: ind_y+i, z: ind_z)
                    }
                case 3:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x-1, y: ind_y+i, z: ind_z+1)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x+1, y: ind_y+i, z: ind_z-1)
                    }
                case 4:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x, y: ind_y+i, z: ind_z+2)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x, y: ind_y+i, z: ind_z-1)
                    }
                case 5:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x+1, y: ind_y+i, z: ind_z+1)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x-1, y: ind_y+i, z: ind_z-1)
                    }
                case 6:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x+2, y: ind_y+i, z: ind_z)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x-1, y: ind_y+i, z: ind_z)
                    }
                case 7:
                    if (acAngle != 6){
                        createParticleVane(x: ind_x+1, y: ind_y+i, z: ind_z-1)
                    }
                    if (acAngle != 7){
                        createParticleVane(x: ind_x-1, y: ind_y+i, z: ind_z+1)
                    }
                default:
                    print("Error, wrong AC direction")
                }
                
            }
            for i in stride(from: 0, to: Float.pi*2, by: Float.pi/16) {
                for j in stride(from: 0, to: 0.075, by: 0.025) {
                    let indicies = convert3DIndex(ind_x, ind_y, ind_z)
                    var velocity = simd_float3(velocityData[indicies.1], velocityData[indicies.1 + 1], velocityData[indicies.1 + 2])
                    velocity = simd_float3(Float(cos(-rotationValue)) * velocity.x + Float(sin(-rotationValue)) * velocity.z,
                                            velocity.y,
                                            -Float(sin(-rotationValue)) * velocity.x + Float(cos(-rotationValue)) * velocity.z)

                    var worldPos = gridArray[indicies.0].position
                    
                    var xzVec1 = simd_float3(1,0,1)
                    xzVec1 = simd.normalize(xzVec1)
                    
                    var xzVec2 = simd_float3(1,0,-1)
                    xzVec2 = simd.normalize(xzVec2)
                    
                    switch modelAC.acOrientation {
                    case 0:
                        worldPos = simd_float3(worldPos.x+0.05,
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z-0.05+(0.15+Float(j))*cos(i))
                    case 1:
                        worldPos = simd_float3(worldPos.x,
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z) - ((0.15+Float(j))*cos(i))*xzVec1
                    case 2:
                        worldPos = simd_float3(worldPos.x-0.05+(0.15+Float(j))*cos(i),
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z-0.05)
                    case 3:
                        worldPos = simd_float3(worldPos.x,
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z) - ((0.15+Float(j))*cos(i))*xzVec2
                    case 4:
                        worldPos = simd_float3(worldPos.x-0.05,
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z+0.05+(0.15+Float(j))*cos(i))
                    case 5:
                        worldPos = simd_float3(worldPos.x,
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z) + ((0.15+Float(j))*cos(i))*xzVec1
                    case 6:
                        worldPos = simd_float3(worldPos.x+0.05+(0.15+Float(j))*cos(i),
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z+0.05)
                    case 7:
                        worldPos = simd_float3(worldPos.x,
                                               worldPos.y+1.67+(0.15+Float(j))*sin(i),
                                               worldPos.z) + ((0.15+Float(j))*cos(i))*xzVec2
                    default:
                        print("Error, wrong AC direction")
                    }
                    
                    worldPos = simd_float3(Float(cos(-rotationValue)) * worldPos.x + Float(sin(-rotationValue)) * worldPos.z,
                                            worldPos.y,
                                            -Float(sin(-rotationValue)) * worldPos.x + Float(cos(-rotationValue)) * worldPos.z)

                    let position = simd_float3(worldPos.x, worldPos.y, worldPos.z)

                    let new_particle = primVert(position: position, normal: simd_float3(0,0,0), color:simd_float4(0,0,0,0))
                    particleNodeArr.append(new_particle)  //add //add //add //add //add
                }
            }
        }  //add //add //add //add //add //add //add
        
        particleCreated = true
    }
    
    func updateParticleVane(currentFrame: ARFrame) {
        updateCamera(frame: currentFrame)
        if particleCreated {
            var particleVerticies: [simd_float3] = []
            for i in 0..<particleNodeArr.count {
                particleVerticies.append(particleNodeArr[i].position)
            }
            
            ArrowTimer += 1
            if ArrowTimer >= 20 {
                startParticleVane()
                ArrowTimer = 0
            }

            var removeArray:[Int] = []
            if particleNodeArr.count > 0 {
                if particleNodeArr.count >= 1000000 {
                    for i in 0 ..< 100 {
                        removeArray.append(i)
                    }
                }
            }
            
            gpuCompute.updateBuffers()
            
            let interpolatedValues = gpuCompute.gpu_interpolate(device: device, commandQueue: sceneView.commandQueue!, verticies: particleVerticies)
            
            for i in 0 ..< particleVerticies.count {
                let newTemp = interpolatedValues.0[i]
                let newDirection = interpolatedValues.1[i]
                
                let velocity = sqrt(pow(newDirection.x, 2) + pow(newDirection.y, 2) + pow(newDirection.z, 2))
                //let length = simd_length(particleNodeArr[i].position - eye)
                
                let largeStep:Float = 0.09
                let smallStep:Float = 0.05
                
                if (velocity < 0.022 || Float(1.0 - min(newTemp.x, 1.0)) > 0.85) && !removeArray.contains(i) {  //add //add //add
                    removeArray.append(i)
                }
                
                var rotFlag:Bool = false
                let largePos = particleNodeArr[i].position + newDirection * largeStep
                let rotPositionLarge = simd_float3(Float(cos(rotationValue)) * largePos.x + Float(sin(rotationValue)) * largePos.z,
                                                   largePos.y,
                                                -Float(sin(rotationValue)) * largePos.x + Float(cos(rotationValue)) * largePos.z)
                
                if rotPositionLarge.x <= boundary_points[0] && rotPositionLarge.x >= boundary_points[1] &&
                    rotPositionLarge.y <= gd.pc_max_y && rotPositionLarge.y >= gd.pc_min_y &&
                    rotPositionLarge.z <= boundary_points[2] && rotPositionLarge.z >= boundary_points[3]{
                    particleNodeArr[i].position.x += newDirection.x * largeStep
                    particleNodeArr[i].position.y += newDirection.y * largeStep
                    particleNodeArr[i].position.z += newDirection.z * largeStep
                }
                else {
                    particleNodeArr[i].position.x += newDirection.x * smallStep
                    particleNodeArr[i].position.y += newDirection.y * smallStep
                    particleNodeArr[i].position.z += newDirection.z * smallStep
                }
                
                let rotPositionX = Float(cos(rotationValue)) * Float(particleNodeArr[i].position.x) + Float(sin(rotationValue)) *
                                    Float(particleNodeArr[i].position.z)
                let rotPositionY = Float(particleNodeArr[i].position.y)
                let rotPositionZ = -Float(sin(rotationValue)) * Float(particleNodeArr[i].position.x) +
                                              Float(cos(rotationValue)) * Float(particleNodeArr[i].position.z)
                
                var rotPosition = simd_float3(rotPositionX, rotPositionY, rotPositionZ)
                
                if rotPosition.x > gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x{
                    rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x - 0.05
                    rotFlag = true
                }
                if rotPosition.x < gridArray[convert3DIndex(0, 0, 0).0].position.x{
                    rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x + 0.05
                    rotFlag = true
                }
                if particleNodeArr[i].position.y > gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y{
                    particleNodeArr[i].position.y = gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y - 0.05
                }
                if particleNodeArr[i].position.y < gridArray[convert3DIndex(0, 0, 0).0].position.y{
                    particleNodeArr[i].position.y = gridArray[convert3DIndex(0, 0, 0).0].position.y + 0.05
                }
                if rotPosition.z > gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z{
                    rotPosition.z = gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z - 0.05
                    rotFlag = true
                }
                if rotPosition.z < gridArray[convert3DIndex(0, 0, 0).0].position.z{
                    rotPosition.z = gridArray[convert3DIndex(0, 0, 0).0].position.z + 0.05
                    rotFlag = true
                }
                
                if rotFlag {
                    particleNodeArr[i].position = simd_float3(Float(cos(-rotationValue)) * rotPosition.x + Float(sin(-rotationValue)) * rotPosition.z,
                                                              rotPosition.y,
                                                           -Float(sin(-rotationValue)) * rotPosition.x + Float(cos(-rotationValue)) * rotPosition.z)
                    rotFlag = false
                }
                
                var newColor = getTemperatureColor(interpolated_temp: newTemp.x)
                if newTemp.y == 0.0 {
                    if !complete_occlude {
                        newColor.w = 1.0
                    }
                    else {
                        newColor.w = 0.0
                    }
                }
                else {
                    newColor.w = 1.0
                }
                
//                if newColor.x == 1.0 {
//                    newColor.w = 0.0
//                    //removeArray.append(i)
//                }
                
                particleNodeArr[i].color = newColor
            }
            removeArray.sort()
            for i in 0..<removeArray.count {  //add //add //add //add
                if removeArray[i] - i < particleNodeArr.count {
                    particleNodeArr.remove(at: removeArray[i] - i)
                }
            }  //add //add //add //add
        }
        bufferNode = particleNodeArr
    }
    
        
    // MARK: - Particle Visualization
    func createParticle(x:Int, y:Int, z:Int) {
        let indicies = convert3DIndex(x, y, z)
        var worldPos = gridArray[indicies.0].position
        worldPos = simd_float3(Float(cos(-rotationValue)) * worldPos.x + Float(sin(-rotationValue)) * worldPos.z,
                                worldPos.y,
                                -Float(sin(-rotationValue)) * worldPos.x + Float(cos(-rotationValue)) * worldPos.z)
        
        if worldPos.x-0.001 + 0.02 < boundary_points[0] && worldPos.x-0.001 + 0.02 > boundary_points[1] && worldPos.y-0.001 + 0.02 < pc_max_y && worldPos.y-0.001 + 0.02 > pc_min_y && worldPos.z-0.001 + 0.02 < boundary_points[2] && worldPos.z-0.001 + 0.02 > boundary_points[3] {
            let position = simd_float3(worldPos.x-0.001 + 0.02, worldPos.y-0.001 + 0.02, worldPos.z-0.001 + 0.02)
            
            let new_particle = primVert(position: position, normal: simd_float3(0,0,0), color:simd_float4(0,0,0,0))
            particleNodeArr.append(new_particle)
        }
            
        
        if worldPos.x-0.001 - 0.02 < boundary_points[0] && worldPos.x-0.001 - 0.02 > boundary_points[1] && worldPos.y-0.001 - 0.02 < pc_max_y && worldPos.y-0.001 - 0.02 > pc_min_y && worldPos.z-0.001 - 0.02 < boundary_points[2] && worldPos.z-0.001 - 0.02 > boundary_points[3] {
            let position = simd_float3(worldPos.x-0.001 - 0.02, worldPos.y-0.001 - 0.02, worldPos.z-0.001 - 0.02)
            
            let new_particle = primVert(position: position, normal: simd_float3(0,0,0), color:simd_float4(0,0,0,0))
            particleNodeArr.append(new_particle)
        }
    }
    
    func startParticle(){
        for i in 0 ..< gridSizeX {
            for j in 0 ..< gridSizeY {
                for k in 0 ..< gridSizeZ {
                    let idx = convert3DIndex(i, j, k)
                    if gridArray[idx.0].occ == false {
                        createParticle(x: i, y: j, z: k)
                    }
                }
            }
        }
        particleCreated = true
    }
    
    func updateParticle(currentFrame: ARFrame) {
        if particleCreated {
            var particleVerticies: [simd_float3] = []
            for i in 0..<particleNodeArr.count {
                particleVerticies.append(particleNodeArr[i].position)
            }

            updateCamera(frame: currentFrame)
            gpuCompute.updateBuffers()
            
            let interpolatedValues = gpuCompute.gpu_interpolate(device: device, commandQueue: sceneView.commandQueue!, verticies: particleVerticies)
            
            for i in 0 ..< particleVerticies.count {
                let newTemp = interpolatedValues.0[i]
                let newDirection = interpolatedValues.1[i]
                let largeStep:Float = 0.1
                let smallStep:Float = 0.04
                                
                if particleNodeArr[i].position.x + newDirection.x * largeStep <= boundary_points[0] && particleNodeArr[i].position.x + newDirection.x * largeStep >= boundary_points[1] && particleNodeArr[i].position.y + newDirection.y * largeStep <= gd.pc_max_y && particleNodeArr[i].position.y + newDirection.y * largeStep >= gd.pc_min_y &&
                    particleNodeArr[i].position.z + newDirection.z * largeStep <= boundary_points[2] && particleNodeArr[i].position.z + newDirection.z * largeStep >= boundary_points[3]{
                    particleNodeArr[i].position.x += newDirection.x * largeStep
                    particleNodeArr[i].position.y += newDirection.y * largeStep
                    particleNodeArr[i].position.z += newDirection.z * largeStep
                }
                else {
                    particleNodeArr[i].position.x += newDirection.x * smallStep
                    particleNodeArr[i].position.y += newDirection.y * smallStep
                    particleNodeArr[i].position.z += newDirection.z * smallStep
                }
                
                if particleNodeArr[i].position.x > gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x{
                    particleNodeArr[i].position.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x - 0.1
                }
                if particleNodeArr[i].position.x < gridArray[convert3DIndex(0, 0, 0).0].position.x{
                    particleNodeArr[i].position.x = gridArray[convert3DIndex(0, 0, 0).0].position.x + 0.1
                }
                if particleNodeArr[i].position.y > gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y{
                    particleNodeArr[i].position.y = gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y - 0.1
                }
                if particleNodeArr[i].position.y < gridArray[convert3DIndex(0, 0, 0).0].position.y{
                    particleNodeArr[i].position.y = gridArray[convert3DIndex(0, 0, 0).0].position.y + 0.1
                }
                if particleNodeArr[i].position.z > gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z{
                    particleNodeArr[i].position.z = gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z - 0.1
                }
                if particleNodeArr[i].position.z < gridArray[convert3DIndex(0, 0, 0).0].position.z{
                    particleNodeArr[i].position.z = gridArray[convert3DIndex(0, 0, 0).0].position.z + 0.1
                }
                
                var newColor = getTemperatureColor(interpolated_temp: newTemp.x)
                if newTemp.y == 0.0 {
                    if !complete_occlude {
                        newColor.w = 1.0
                    }
                    else {
                        newColor.w = 0.0
                    }
                }
                else {
                    newColor.w = 1.0
                }
                
                let length:Float = particleDistance
                if let currentFrame = sceneView.session.currentFrame {
                    let camera = currentFrame.camera
                    let view_matrix = camera.viewMatrix(for: UIInterfaceOrientation.landscapeRight).transpose.inverse
                    let n = simd_float3(view_matrix[0,2], view_matrix[1,2], view_matrix[2,2])
                    let At = -1*n

                    let vector0:simd_float3 = At * length
                    let vector1:simd_float3 = At * (length+1.5)
                    let point0:simd_float3 = eye + At * length
                    let point1:simd_float3 = eye + At * (length+1.5)
                    let particleVector0 = point0 - particleNodeArr[i].position
                    let particleVector1 = point1 - particleNodeArr[i].position
                    
                    if acos(dot(vector0, particleVector0)/(simd_length(vector0)*simd_length(particleVector0))) < 1.5708 || acos(dot(vector1, particleVector1)/(simd_length(vector1)*simd_length(particleVector1))) > 1.5708 {
                        newColor.w = 0.0
                    }
                }
                
//                if length < particleDistance || newColor.x == 1.0 {
//                    newColor.w = 0.0
//                }
                particleNodeArr[i].color = newColor
            }
        }
        bufferNode = particleNodeArr
    }
    
    // MARK: - Stream surface, line Visualization
//    func addLine(start: SCNVector3, end: SCNVector3) {
//        let cylinderLineNode = SCNGeometry.cylinderLine(from: start,
//                                                          to: end,
//                                                    segments: 6)
//        lineArray.append(cylinderLineNode)
//        sceneView.scene.rootNode.addChildNode(cylinderLineNode)
//    }
    
    //line
    func StartLines()
    {
        let rotACPosition = simd_float3(Float(cos(rotationValue)) * modelAC.currentPosition.x + Float(sin(rotationValue)) * modelAC.currentPosition.z,
                                        modelAC.currentPosition.y,
                                        -Float(sin(rotationValue)) * modelAC.currentPosition.x + Float(cos(rotationValue)) * modelAC.currentPosition.z)
        
        var ind_x = Int(Float(gridSizeX)*(rotACPosition.x - boundary_points[1])/gd.gridLengthX)
        var ind_y = Int(Float(gridSizeY)*(rotACPosition.y - pc_min_y)/gd.gridLengthY)
        var ind_z = Int(Float(gridSizeZ)*(rotACPosition.z - boundary_points[3])/gd.gridLengthZ)

        if ind_x >= gridSizeX{
            ind_x = gridSizeX - 1
        }
        else if ind_x < 0 {
            ind_x = 0
        }
        if ind_y >= gridSizeY{
            ind_y = gridSizeY - 1
        }
        else if ind_y < 0 {
            ind_x = 0
        }
        if ind_z >= gridSizeZ{
            ind_z = gridSizeZ - 1
        }
        else if ind_z < 0 {
            ind_z = 0
        }
        
        let idx = convert3DIndex(ind_x, ind_y, ind_z).0 //check!!
        let pos:simd_float3 = gridArray[idx].position
        
        lineCnt = 0
        
        if (modelAC.currentACModel == "ceiling")
        {
            var i:Float = -2
            while i <= 2
            {
                var tempPos = simd_float3(pos.x + i * 0.1 , pos.y, pos.z - 0.42) + simd_float3(0, -0.17, 0)
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                lineCnt += 1
                
                tempPos = simd_float3(pos.x + 0.42, pos.y, pos.z + i * 0.1) + simd_float3(0, -0.17, 0)
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                lineCnt += 1
                
                tempPos = simd_float3(pos.x - 0.42, pos.y, pos.z + i * 0.1) + simd_float3(0, -0.17, 0)
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                lineCnt += 1
                
                tempPos = simd_float3(pos.x + i * 0.1 , pos.y, pos.z + 0.42) + simd_float3(0, -0.17, 0)
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                lineCnt += 1
                
                i += 0.25
            }
        }
        else if modelAC.currentACModel == "tower"
        {
            if modelAC.acOrientation % 2 == 0
            {
                var horX:Float = 0
                var horZ:Float = 0 //right-end direction
                
                if modelAC.acOrientation == 0
                {
                    horX = 0
                    horZ = 1
                }
                else if modelAC.acOrientation == 2
                {
                    horX = 1
                    horZ = 0
                }
                else if modelAC.acOrientation == 4
                {
                    horX = 0
                    horZ = -1
                }
                else if modelAC.acOrientation == 6
                {
                    horX = -1
                    horZ = 0
                }

                for i in 0 ... 16
                {
                    var tempPos = simd_float3(pos.x - 0.2 * horX, pos.y + 0.5 + 0.025 * Float(i), pos.z - 0.2 * horZ)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                    
                    tempPos = simd_float3(pos.x - 0.2 * horX, pos.y + 1.0 + 0.025 * Float(i), pos.z - 0.2 * horZ)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                    
                    tempPos = simd_float3(pos.x + 0.1 * horX, pos.y + 0.5 + 0.025 * Float(i), pos.z + 0.1 * horZ)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                    
                    tempPos = simd_float3(pos.x + 0.1 * horX, pos.y + 1.0 + 0.025 * Float(i), pos.z + 0.1 * horZ)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                }

                //circle
                var tempPos = simd_float3(pos.x - 0.05 * horX, pos.y + 1.65, pos.z - 0.05 * horZ)
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                let center:simd_float3 = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                
                tempPos = simd_float3(-0.15 * horX, 0, -0.15 * horZ)
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                let hor:simd_float3 = simd_float3(tempPos.x, tempPos.y, tempPos.z)

                let numRing:Int = 16
                for i in 0 ..< numRing
                {
                    let theta:Float = Float(i) * 2 * 3.141592 / Float(numRing)
                    streamlines[lineCnt][0] = simd_float3(center.x + (hor.x * cos(theta)), center.y + 0.15 * sin(theta), center.z + (hor.z * cos(theta)))
                    lineCnt += 1
                }
            }
            else
            {
                var horX:Float = 0
                var horZ:Float = 0 //right-end direction
                
                if (modelAC.acOrientation == 1)
                {
                    horX = 1;
                    horZ = 1;
                }
                else if (modelAC.acOrientation == 3)
                {
                    horX = 1;
                    horZ = -1;
                }
                else if (modelAC.acOrientation == 5)
                {
                    horX = -1;
                    horZ = -1;
                }
                else if (modelAC.acOrientation == 7)
                {
                    horX = -1;
                    horZ = 1;
                }
                
                for i in 0 ... 16
                {
                    var tempPos = simd_float3(pos.x - horX * 0.1, pos.y + 0.5 + 0.025 * Float(i), pos.z - horZ * 0.1)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                    
                    tempPos = simd_float3(pos.x - horX * 0.1, pos.y + 1.0 + 0.025 * Float(i), pos.z - horZ * 0.1)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                    
                    tempPos = simd_float3(pos.x + horX * 0.1, pos.y + 0.5 + 0.025 * Float(i), pos.z + horZ * 0.1)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                    
                    tempPos = simd_float3(pos.x + horX * 0.1, pos.y + 1.0 + 0.025 * Float(i), pos.z + horZ * 0.1)
                    tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                          tempPos.y,
                                            -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                    streamlines[lineCnt][0] = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                    lineCnt += 1
                }

                //circle
                var tempPos = simd_float3(pos.x, pos.y + 1.65, pos.z);
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                let center:simd_float3 = simd_float3(tempPos.x, tempPos.y, tempPos.z)
                
                tempPos = simd_float3(-0.15 / sqrt(2) * horX, 0, -0.15 / sqrt(2) * horZ)
                tempPos = simd_float3(Float(cos(-rotationValue)) * tempPos.x + Float(sin(-rotationValue)) * tempPos.z,
                                      tempPos.y,
                                        -Float(sin(-rotationValue)) * tempPos.x + Float(cos(-rotationValue)) * tempPos.z)
                let hor:simd_float3 = simd_float3(tempPos.x, tempPos.y, tempPos.z)

                let numRing:Int = 16
                for i in 0 ..< numRing
                {
                    let theta:Float = Float(i) * 2 * 3.141592 / Float(numRing)
                    streamlines[lineCnt][0] = simd_float3(center.x + (hor.x * cos(theta)), center.y + 0.15 * sin(theta), center.z + (hor.z * cos(theta)))
                    lineCnt += 1
                }
                
            }

        }   //end tower
    }
    
    func updateLines()
    {
        if surfaceStarted
        {
            lineTimer += 0.1
            
            //StartLines()

            for s in 0 ..< lineCnt
            {
                for i in 0 ..< maxLineStLen - 1
                {
                    let velTemper = getVelocityTemper(pos: streamlines[s][i])
                    let vel:simd_float3 = velTemper.1
                    let temper = velTemper.0
                    if temper.y == 0.0 && complete_occlude{
//                        lineOcclude[s][i] = true
                    }
                    streamlines[s][i + 1] = streamlines[s][i] + lineParticleSpeed * vel
                    
                    var rotFlag:Bool = false
                    
                    let rotPositionX = Float(cos(rotationValue)) * Float(streamlines[s][i + 1].x) +
                                        Float(sin(rotationValue)) * Float(streamlines[s][i + 1].z)
                    let rotPositionY = Float(streamlines[s][i + 1].y)
                    let rotPositionZ = -Float(sin(rotationValue)) * Float(streamlines[s][i + 1].x) +
                                                  Float(cos(rotationValue)) * Float(streamlines[s][i + 1].z)
                    
                    var rotPosition = simd_float3(rotPositionX, rotPositionY, rotPositionZ)
                    
                    if rotPosition.x > gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x{
                        rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x - 0.05
                        rotFlag = true
                    }
                    if rotPosition.x < gridArray[convert3DIndex(0, 0, 0).0].position.x{
                        rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x + 0.05
                        rotFlag = true
                    }
                    if streamlines[s][i + 1].y > gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y{
                        streamlines[s][i + 1].y = gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y - 0.05
                    }
                    if streamlines[s][i + 1].y < gridArray[convert3DIndex(0, 0, 0).0].position.y{
                        streamlines[s][i + 1].y = gridArray[convert3DIndex(0, 0, 0).0].position.y + 0.05
                    }
                    if rotPosition.z > gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z{
                        rotPosition.z = gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z - 0.05
                        rotFlag = true
                    }
                    if rotPosition.z < gridArray[convert3DIndex(0, 0, 0).0].position.z{
                        rotPosition.z = gridArray[convert3DIndex(0, 0, 0).0].position.z + 0.05
                        rotFlag = true
                    }
                    
                    if rotFlag {
                        streamlines[s][i + 1] = simd_float3(Float(cos(-rotationValue)) * rotPosition.x +
                                                            Float(sin(-rotationValue)) * rotPosition.z,
                                                                  rotPosition.y,
                                                -Float(sin(-rotationValue)) * rotPosition.x + Float(cos(-rotationValue)) * rotPosition.z)
                        rotFlag = false
                    }
                }
            }

            //AssignLineRenderer()
            AssignLineIndexRenderer()
        }
    }
    
    func AssignLineIndexRenderer()
    {
        lineVerticesCount = 0
        lineVerticesIndex = 0
        
        guard let currentFrame = sceneView.session.currentFrame else { return }
        updateCamera(frame: currentFrame)
        
        let isCeiling = modelAC.currentACModel == "ceiling"
        
        for s in 0 ..< lineCnt
        {
            for i in 0 ..< maxLineStLen
            {
                var turn:Int = 5 * HashBig(x:s, n:70) + i - Int(lineTimer * lineSpeed)
                turn = turn % 70
                while (turn < 0)
                {
                    turn += 70
                }
//                if(i == 0){
//                    turn = 0;
//                }
//                else{
//                    turn = 1;
//                }
                if (turn == 0)
                {
                    let len = min(lineLength, maxLineStLen - i - 1)
//                    let len = maxLineStLen - i - 1
                    //let len = 3
                    if len == 1
                    {
                        continue
                        
//                        lineVertices[lineVerticesCount] = streamlines[s][i] + (isCeiling ? simd_float3(0,0.1,0) : simd_float3.zero)
//                        lineVertices[lineVerticesCount + 1] = streamlines[s][i + 1] + (isCeiling ? simd_float3(0,0.1,0) :                                                                                                   simd_float3.zero)
//
//                        let halfpoint:simd_float3 = (lineVertices[lineVerticesCount + 1] + lineVertices[lineVerticesCount]) / 2
//                        var ver1:simd_float3 = cross(lineVertices[lineVerticesCount + 1] - lineVertices[lineVerticesCount],
//                                                    halfpoint - gd.eye)
//                        var ver2:simd_float3 = cross(lineVertices[lineVerticesCount + 1] - lineVertices[lineVerticesCount],
//                                                    ver1)
//                        ver1 = simd_normalize(ver1)
//                        ver2 = simd_normalize(ver2)
//
//                        var dir = lineVertices[lineVerticesCount + 1] - lineVertices[lineVerticesCount]
//                        if lineWidthScale > simd_length(dir)
//                        {
//                            dir = simd_normalize(dir)
//                            lineVertices[lineVerticesCount] = halfpoint - dir * lineWidthScale / 2.0
//                            lineVertices[lineVerticesCount + 1] = halfpoint + dir * lineWidthScale / 2.0
//                        }
//
//                        lineVertices[lineVerticesCount + 2] = halfpoint + ver1 * lineWidthScale / 2.0
//                        lineVertices[lineVerticesCount + 3] = halfpoint - ver1 * lineWidthScale / 2.0
//
//                        lineVertices[lineVerticesCount + 4] = halfpoint + ver2 * lineWidthScale / 2.0
//                        lineVertices[lineVerticesCount + 5] = halfpoint - ver2 * lineWidthScale / 2.0
//
//                        //1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 4)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 3)
//                        lineVerticesIndex += 1
//
//                        //2
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 4)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 3)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 1)
//                        lineVerticesIndex += 1
//
//                        //3
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 4)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 2)
//                        lineVerticesIndex += 1
//
//                        //4
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 4)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 2)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 1)
//                        lineVerticesIndex += 1
//
//                        //5
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 3)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 5)
//                        lineVerticesIndex += 1
//
//                        //6
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 3)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 5)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 1)
//                        lineVerticesIndex += 1
//
//                        //7
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 2)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 5)
//                        lineVerticesIndex += 1
//
//                        //8
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 2)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 5)
//                        lineVerticesIndex += 1
//                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 1)
//                        lineVerticesIndex += 1
//
//                        lineVerticesCount += 6
                    }
                    else if len > 2
                    {
                        var point1 = streamlines[s][i] + (isCeiling ? simd_float3(0,0.1,0) : simd_float3.zero)
                        var point2 = streamlines[s][i + 1] + (isCeiling ? simd_float3(0,0.1,0) : simd_float3.zero)
                        
                        var ver:simd_float3 = cross(point2 - point1, point2 - gd.eye)
                        ver = simd_normalize(ver)
                        
                        lineVertices[lineVerticesCount] = point1
                        lineVertices[lineVerticesCount + 1] = point2 + ver * lineWidthScale / 2.0
                        lineVertices[lineVerticesCount + 2] = point2 - ver * lineWidthScale / 2.0
                        
                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
                        lineVerticesIndex += 1
                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 1)
                        lineVerticesIndex += 1
                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 2)
                        lineVerticesIndex += 1
                        
                        lineVerticesCount += 3
                        
                        for ii in 2 ..< len
                        {
                            point1 = point2
                            point2 = streamlines[s][i + ii] + (isCeiling ? simd_float3(0,0.1,0) : simd_float3.zero)
                            
                            ver = cross(point2 - point1, point2 - gd.eye)
                            ver = simd_normalize(ver)
                            
                            lineVertices[lineVerticesCount] = point2 + ver * lineWidthScale / 2.0
                            lineVertices[lineVerticesCount + 1] = point2 - ver * lineWidthScale / 2.0
                            
                            lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount - 2)
                            lineVerticesIndex += 1
                            lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount - 1)
                            lineVerticesIndex += 1
                            lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
                            lineVerticesIndex += 1
                            
                            lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount - 1)
                            lineVerticesIndex += 1
                            lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
                            lineVerticesIndex += 1
                            lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount + 1)
                            lineVerticesIndex += 1
                            
                            lineVerticesCount += 2
                        }
                        lineVertices[lineVerticesCount] = streamlines[s][i + len] + (isCeiling ? simd_float3(0,0.1,0) : simd_float3.zero)
                        
                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount - 2)
                        lineVerticesIndex += 1
                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount - 1)
                        lineVerticesIndex += 1
                        lineIndices[lineVerticesIndex] = UInt32(lineVerticesCount)
                        lineVerticesIndex += 1
                        
                        lineVerticesCount += 1
                    }
                }
            }
        }
        
        for i in 0 ..< lineVerticesCount {
            lineVerticesColors[i] = lineColor
        }
    }
    
    func AssignLineRenderer()
    {
        //var lineNodeCount:Int = 0
        
        for s in 0 ..< lineCnt
        {
            for i in 0 ..< maxLineStLen - 1
            {
                var turn:Int = 5 * HashBig(x:s, n:70) + i - Int(lineTimer * lineSpeed)
                turn = turn % 70
                while (turn < 0)
                {
                    turn += 70
                }

                if (turn <= 3)
                {
//                    lineNodeCount += 1
//                    if lineNodeCount > lineArray.count {
//                        addLine(start: SCNVector3(streamlines[s][i].x, streamlines[s][i].y + 0.1, streamlines[s][i].z),
//                                end: SCNVector3(streamlines[s][i+1].x, streamlines[s][i+1].y + 0.1, streamlines[s][i+1].z))
//                    }
//                    else
//                    {
//                        let from = SCNVector3(streamlines[s][i].x, streamlines[s][i].y + 0.1, streamlines[s][i].z)
//                        let to = SCNVector3(streamlines[s][i+1].x, streamlines[s][i+1].y + 0.1, streamlines[s][i+1].z)
//
//                        let x1 = from.x
//                        let x2 = to.x
//
//                        let y1 = from.y
//                        let y2 = to.y
//
//                        let z1 = from.z
//                        let z2 = to.z
//
//                        let distance =  sqrtf( (x2-x1) * (x2-x1) +
//                                               (y2-y1) * (y2-y1) +
//                                               (z2-z1) * (z2-z1) )
//
//                        lineArray[lineNodeCount-1].position = SCNVector3(x: (from.x + to.x) / 2,
//                                                                         y: (from.y + to.y) / 2,
//                                                                         z: (from.z + to.z) / 2)
//
//                        lineArray[lineNodeCount-1].scale = SCNVector3(1,distance,1)
//
//                        lineArray[lineNodeCount-1].eulerAngles = SCNVector3(Float.pi / 2,
//                                                          acos((to.z-from.z)/distance),
//                                                          atan2((to.y-from.y),(to.x-from.x)))
//                    }
                }
            }
        }
//        if lineNodeCount < lineArray.count {
//            for i in lineNodeCount ..< lineArray.count {
//                lineArray[i].removeFromParentNode()
//            }
//            let range = lineNodeCount ... lineArray.count - 1
//            lineArray.removeSubrange(range)
//        }
    }
    
    func StreamlinePointIdx(s:Int, i:Int) -> Int
    {
        return s * maxStLen + i
    }
    
    //surface
    func startSurface() {
        let rotACPosition = simd_float3(Float(cos(rotationValue)) * modelAC.currentPosition.x + Float(sin(rotationValue)) * modelAC.currentPosition.z,
                                        modelAC.currentPosition.y,
                                        -Float(sin(rotationValue)) * modelAC.currentPosition.x + Float(cos(rotationValue)) * modelAC.currentPosition.z)
        
        var ind_x = Int(Float(gridSizeX)*(rotACPosition.x - boundary_points[1])/gd.gridLengthX)
        var ind_y = Int(Float(gridSizeY)*(rotACPosition.y - pc_min_y)/gd.gridLengthY)
        var ind_z = Int(Float(gridSizeZ)*(rotACPosition.z - boundary_points[3])/gd.gridLengthZ)

        if ind_x >= gridSizeX{
            ind_x = gridSizeX - 1
        }
        else if ind_x < 0 {
            ind_x = 0
        }
        if ind_y >= gridSizeY{
            ind_y = gridSizeY - 1
        }
        else if ind_y < 0 {
            ind_x = 0
        }
        if ind_z >= gridSizeZ{
            ind_z = gridSizeZ - 1
        }
        else if ind_z < 0 {
            ind_z = 0
        }
        
        if modelAC.currentACModel == "ceiling" {
            let nodeCnt:Int = 16
            let interval:Int = (maxNodeCnt - 1) / nodeCnt
            for i in 0 ... nodeCnt {
                let ii:Int = interval * i
                
                let nodeOff:Float = (Float(i) * 4.0 / Float(nodeCnt) - 2.0) * 0.1
                
                var idx = convert3DIndex(ind_x - 4, ind_y, ind_z).0 //check!!
                var pos:simd_float3 = gridArray[idx].position
                pos = simd_float3(pos.x, pos.y, pos.z + nodeOff)
                pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                  pos.y,
                                        -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                surfaces[2].gridPos[ii][0] = simd_float3(pos.x, pos.y, pos.z)
                
                idx = convert3DIndex(ind_x + 4, ind_y, ind_z).0 //check!!
                pos = gridArray[idx].position
                pos = simd_float3(pos.x, pos.y, pos.z + nodeOff)
                pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                  pos.y,
                                        -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                surfaces[1].gridPos[ii][0] = simd_float3(pos.x, pos.y, pos.z)
                
                idx = convert3DIndex(ind_x, ind_y, ind_z - 4).0 //check!!
                pos = gridArray[idx].position
                pos = simd_float3(pos.x + nodeOff, pos.y, pos.z)
                pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                  pos.y,
                                        -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                surfaces[0].gridPos[ii][0] = simd_float3(pos.x, pos.y, pos.z)
                
                idx = convert3DIndex(ind_x, ind_y, ind_z + 4).0 //check!!
                pos = gridArray[idx].position
                pos = simd_float3(pos.x + nodeOff, pos.y, pos.z)
                pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                  pos.y,
                                        -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                surfaces[3].gridPos[ii][0] = simd_float3(pos.x, pos.y, pos.z)

                for s in 0 ..< surfaceCnt
                {
                    surfaces[s].gridPos[ii][0].y -= 0.17
                    surfaces[s].nextIdx[ii][0] = i == nodeCnt ? -1 : ii + interval
                }
            }
        }
        else if modelAC.currentACModel == "tower"
        {
            var idx = convert3DIndex(ind_x, ind_y, ind_z).0 //check!!
            var pos:simd_float3 = gridArray[idx].position
            
            if (modelAC.acOrientation % 2 == 0)
            {
                var ventLeft:simd_float3 = simd_float3.zero
                var ventRight:simd_float3 = simd_float3.zero
                
                if (modelAC.acOrientation == 0)
                {
                    idx = convert3DIndex(ind_x, ind_y, ind_z - 2).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x, ind_y, ind_z + 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }
                else if (modelAC.acOrientation == 2)
                {
                    idx = convert3DIndex(ind_x - 2, ind_y, ind_z).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x + 1, ind_y, ind_z).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }
                else if (modelAC.acOrientation == 4)
                {
                    idx = convert3DIndex(ind_x, ind_y, ind_z + 2).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x, ind_y, ind_z - 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }
                else if (modelAC.acOrientation == 6)
                {
                    idx = convert3DIndex(ind_x + 2, ind_y, ind_z).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x - 1, ind_y, ind_z).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }

                let nodeCnt:Int = 16
                let interval:Int = (maxNodeCnt - 1) / nodeCnt
                for i in 0 ... nodeCnt
                {
                    let ii:Int = interval * i
                    surfaces[0].gridPos[ii][0] = ventLeft + simd_float3(0, 0.45 + Float(i) * 0.4 / Float(nodeCnt), 0)
                    surfaces[1].gridPos[ii][0] = ventLeft + simd_float3(0, 0.95 + Float(i) * 0.4 / Float(nodeCnt), 0)
                    surfaces[2].gridPos[ii][0] = ventRight + simd_float3(0, 0.45 + Float(i) * 0.4 / Float(nodeCnt), 0)
                    surfaces[3].gridPos[ii][0] = ventRight + simd_float3(0, 0.95 + Float(i) * 0.4 / Float(nodeCnt), 0)
                    
                    for s in 0 ..< 4
                    {
                        surfaces[s].nextIdx[ii][0] = (i == nodeCnt) ? -1 : (ii + interval)
                    }
                }

//                {   //circle
//                    Vector3 center = ((Vector3)ventLeft + ventRight) / 2.0f + new Vector3(0, 16.5f, 0)
//                    Vector3 hor = ((Vector3)ventLeft - ventRight) / 2.0f
//                    Vector3 ver = new Vector3(0, 1.5f, 0)
//
//                    int numRing = 16
//                    interval = (maxNodeCnt - 1) / numRing
//                    for (int i = 0; i <= numRing; i++)
//                    {
//                        int ii = interval * i
//                        float theta = i * 2 * Mathf.PI / numRing
//                        surfaces[4].gridPos[ii, 0] = center + 1.1f * (hor * Mathf.Cos(theta) + ver * Mathf.Sin(theta))
//
//                        surfaces[4].nextIdx[ii, 0] = ii + interval
//                    }
//                    surfaces[4].nextIdx[interval * numRing, 0] = -1
//                }   //end circle
            }
            else
            {
                var ventLeft = simd_float3.zero
                var ventRight = simd_float3.zero
                if (modelAC.acOrientation == 1)
                {
                    idx = convert3DIndex(ind_x - 1, ind_y, ind_z - 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x + 1, ind_y, ind_z + 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }
                else if (modelAC.acOrientation == 3)
                {
                    idx = convert3DIndex(ind_x - 1, ind_y, ind_z + 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x + 1, ind_y, ind_z - 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }
                else if (modelAC.acOrientation == 5)
                {
                    idx = convert3DIndex(ind_x + 1, ind_y, ind_z + 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x - 1, ind_y, ind_z - 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }
                else if (modelAC.acOrientation == 7)
                {
                    idx = convert3DIndex(ind_x + 1, ind_y, ind_z - 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventLeft = simd_float3(pos.x, pos.y, pos.z)
                    
                    idx = convert3DIndex(ind_x - 1, ind_y, ind_z + 1).0 //check!!
                    pos = gridArray[idx].position
                    pos = simd_float3(Float(cos(-rotationValue)) * pos.x + Float(sin(-rotationValue)) * pos.z,
                                      pos.y,
                                            -Float(sin(-rotationValue)) * pos.x + Float(cos(-rotationValue)) * pos.z)
                    ventRight = simd_float3(pos.x, pos.y, pos.z)
                }

                let nodeCnt:Int = 16
                let interval:Int = (maxNodeCnt - 1) / nodeCnt
                for i in 0 ... nodeCnt
                {
                    let ii:Int = interval * i
                    surfaces[0].gridPos[ii][0] = ventLeft + simd_float3(0, 0.45 + Float(i) * 0.4 / Float(nodeCnt), 0)
                    surfaces[1].gridPos[ii][0] = ventLeft + simd_float3(0, 0.95 + Float(i) * 0.4 / Float(nodeCnt), 0)
                    surfaces[2].gridPos[ii][0] = ventRight + simd_float3(0, 0.45 + Float(i) * 0.4 / Float(nodeCnt), 0)
                    surfaces[3].gridPos[ii][0] = ventRight + simd_float3(0, 0.95 + Float(i) * 0.4 / Float(nodeCnt), 0)

                    for s in 0 ..< 4
                    {
                        surfaces[s].nextIdx[ii][0] = (i == nodeCnt) ? -1 : (ii + interval)
                    }
                }

//                {   //circle
//                    Vector3 center = ((Vector3)ventLeft + ventRight) / 2.0f + new Vector3(0, 16.5f, 0)
//                    Vector3 hor = ((Vector3)ventLeft - ventRight) / 2.0f
//                    Vector3 ver = new Vector3(0, 1.5f, 0)
//
//                    int numRing = 16
//                    interval = (maxNodeCnt - 1) / numRing
//                    for (int i = 0; i <= numRing; i++)
//                    {
//                        int ii = interval * i
//                        float theta = i * 2 * Mathf.PI / numRing
//                        surfaces[4].gridPos[ii, 0] = center + 1.1f * (hor * Mathf.Cos(theta) + ver * Mathf.Sin(theta))
//
//                        surfaces[4].nextIdx[ii, 0] = ii + interval
//                    }
//                    surfaces[4].nextIdx[interval * numRing, 0] = -1
//                }   //end circle
            }
        }   //end tower


        surfaceStarted = true
    }
    
    func SurfacePointIdx(s:Int, i:Int, j:Int) -> UInt32
    {
        return UInt32(s * (maxNodeCnt * stLen) + j * maxNodeCnt + i)
        //return j * (maxNodeCnt * surfaceCnt) + s * maxNodeCnt + i
    }
    
    func updateSurface()
    {
        if surfaceStarted {
            let rotACPosition = simd_float3(Float(cos(rotationValue)) * modelAC.currentPosition.x + Float(sin(rotationValue)) * modelAC.currentPosition.z,
                                            modelAC.currentPosition.y,
                                            -Float(sin(rotationValue)) * modelAC.currentPosition.x + Float(cos(rotationValue)) * modelAC.currentPosition.z)
            
            var ind_x = Int(Float(gridSizeX)*(rotACPosition.x - boundary_points[1])/gd.gridLengthX)
            var ind_y = Int(Float(gridSizeY)*(rotACPosition.y - pc_min_y)/gd.gridLengthY)
            var ind_z = Int(Float(gridSizeZ)*(rotACPosition.z - boundary_points[3])/gd.gridLengthZ)

            if ind_x >= gridSizeX{
                ind_x = gridSizeX - 1
            }
            else if ind_x < 0 {
                ind_x = 0
            }
            if ind_y >= gridSizeY{
                ind_y = gridSizeY - 1
            }
            else if ind_y < 0 {
                ind_x = 0
            }
            if ind_z >= gridSizeZ{
                ind_z = gridSizeZ - 1
            }
            else if ind_z < 0 {
                ind_z = 0
            }
            
            let acIdx = convert3DIndex(ind_x, ind_y, ind_z).0 //check!!
            let pos:simd_float3 = gridArray[acIdx].position
            
            if (stLen<maxStLen){
                //while (timer > longerAt)
                //{
                //    stLen++
                //    longerAt += period
                //}
                //if (stLen > maxStLen) stLen = maxStLen
                stLen = maxStLen;
            }
            
            for s in 0 ..< surfaceCnt
            {
                var i:Int = 0
                var i1:Int = surfaces[s].nextIdx[i][0]
                while i1 != -1
                {
                    surfaces[s].areaZero[i] = simd_length(surfaces[s].gridPos[i][0] - surfaces[s].gridPos[i1][0])
                    surfaces[s].valid[i][0] = true
                    surfaces[s].opacity[i][0] = 0.0
                    i = i1
                    i1 = surfaces[s].nextIdx[i1][0]
                }
                surfaces[s].opacity[i][0] = 0.0
            }
            //startSurface() //매 프레임?????
            //Vcnt = 68;
            //for (int s = 0; s < surfaceCnt; s++)
            //{
            //    for (int i = 0; i < 16; i++)
            //    {
            //        int ii = 4 * i
            //        surfaces[s].areaZero[ii] = (surfaces[s].gridPos[ii, 0] - surfaces[s].gridPos[ii + 4, 0]).magnitude
            //    }
            //}

            for j in 1 ..< stLen
            {
                //gpu_precompute
    //            if (use_gpu)
    //            {
    //                for s in 0 ..< surfaceCnt
    //                {
    //                    for q in 0 ..< maxNodeCnt
    //                    {
    //                        let idx:Int = q + s * maxNodeCnt
    //                        verticesBuffer[3 * idx] = surfaces[s].gridPos[q][j - 1].x
    //                        verticesBuffer[3 * idx + 1] = surfaces[s].gridPos[q][j - 1].y
    //                        verticesBuffer[3 * idx + 2] = surfaces[s].gridPos[q][j - 1].z
    //
    //                    }
    //                }
    //                let totalNodeCnt:Int = surfaceCnt * maxNodeCnt
    //                var batch:Int = totalNodeCnt % 128 == 0 ? totalNodeCnt / 128 : totalNodeCnt / 128 + 1
    //                if batch > 8000 {
    //                    batch = 8000
    //                }
    //                if batch > 0
    //                {
    //                    Simulation.Instance.SetShaderBuffer(totalNodeCnt);
    //                    Simulation.Instance.DispatchShader(1, batch);
    //                    Simulation.Instance.CopyShaderOutput(totalNodeCnt);
    //                }
    //            }
                for s in 0 ..< surfaceCnt
                {
                    //i: current node, i1 = i+1, i_1 = i-1, _i = (pred of i)

                    var i_1:Int = 0
                    var i:Int = 0
                    while i != -1
                    {   //advection
                        surfaces[s].pred[i][j] = i
                        surfaces[s].succ[i][j - 1] = i
                        surfaces[s].valid[i][j] = surfaces[s].valid[i][j - 1]

                        //var vel:simd_float3 = simd_float3.zero
                        var vel:simd_float3 = simd_float3(0.05,0.0,0.0)
                        //Vcnt++;

                        if surfaces[s].valid[i][j - 1] || surfaces[s].valid[i_1][j - 1]
                        {
                            if (use_gpu)
                            {
                                //vel = outputBuffer[i + s * maxNodeCnt].vel
                            }
                            else
                            {
                                let velTemper = getVelocityTemper(pos: surfaces[s].gridPos[i][j - 1])
                                vel = velTemper.1
                                let temper = velTemper.0
                                if temper.y == 0.0 && complete_occlude{
                                    //surfaces[s].occlude[i][j - 1] = true
                                }
                            }

                            if(true)    //normalize ??
                            {
                                let mag:Float = simd_length(vel)
                                if mag < cutOffVelocity
                                {
                                    surfaces[s].valid[i][j] = false
                                    vel = simd_float3.zero
                                }
                                else
                                {
                                    vel /= mag
                                }

                            }
                            surfaces[s].gridPos[i][j] = surfaces[s].gridPos[i][j - 1] + vel * particleSpeed
                            
                            var rotFlag:Bool = false
                            
                            let rotPositionX = Float(cos(rotationValue)) * Float(surfaces[s].gridPos[i][j].x) + Float(sin(rotationValue)) * Float(surfaces[s].gridPos[i][j].z)
                            let rotPositionY = Float(streamlines[s][i + 1].y)
                            let rotPositionZ = -Float(sin(rotationValue)) * Float(surfaces[s].gridPos[i][j].x) +
                                                          Float(cos(rotationValue)) * Float(surfaces[s].gridPos[i][j].z)
                            
                            var rotPosition = simd_float3(rotPositionX, rotPositionY, rotPositionZ)
                            
                            if rotPosition.x > gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x{
                                rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x - 0.05
                                rotFlag = true
                            }
                            else if rotPosition.x < gridArray[convert3DIndex(0, 0, 0).0].position.x{
                                rotPosition.x = gridArray[convert3DIndex(gridSizeX-1, 0, 0).0].position.x + 0.05
                                rotFlag = true
                            }
                            if surfaces[s].gridPos[i][j].y > gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y{
                                surfaces[s].gridPos[i][j].y = gridArray[convert3DIndex(0, gridSizeY-1, 0).0].position.y - 0.05
                            }
                            else if surfaces[s].gridPos[i][j].y < gridArray[convert3DIndex(0, 0, 0).0].position.y{
                                surfaces[s].gridPos[i][j].y = gridArray[convert3DIndex(0, 0, 0).0].position.y + 0.05
                            }
                            if rotPosition.z > gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z{
                                rotPosition.z = gridArray[convert3DIndex(0, 0, gridSizeZ-1).0].position.z - 0.05
                                rotFlag = true
                            }
                            else if rotPosition.z < gridArray[convert3DIndex(0, 0, 0).0].position.z{
                                rotPosition.z = gridArray[convert3DIndex(0, 0, 0).0].position.z + 0.05
                                rotFlag = true
                            }
                            
                            if rotFlag {
                                surfaces[s].gridPos[i][j] = simd_float3(Float(cos(-rotationValue)) * rotPosition.x + Float(sin(-rotationValue)) * rotPosition.z,
                                                                          rotPosition.y,
                                            -Float(sin(-rotationValue)) * rotPosition.x + Float(cos(-rotationValue)) * rotPosition.z)
                                rotFlag = false
                            }
                            //Simulation.Instance.no_stick(ref surfaces[s].gridPos[i][j])
                            // stick!!
                        }

                        if i != 0 {
                            surfaces[s].nextIdx[i_1][j] = i
                        }
                        
//                        surfaces[s].opacity[i][j] = 0.7
                        i_1 = i
                        i = surfaces[s].nextIdx[i][j - 1]
                    }
                    surfaces[s].nextIdx[i_1][j] = -1

                    //splitting
                    i_1 = 0
                    i = 0
                    var i1:Int = surfaces[s].nextIdx[0][j]

                    while i1 != -1
                    {
                        if i1 - i <= 1 {
                            i_1 = i
                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }
                        if !surfaces[s].valid[i][j] {
                            i_1 = i
                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }

                        let i_new:Int = (i + i1) / 2
                        let i2:Int = surfaces[s].nextIdx[i1][j]

                        var splitFlag:Bool = false

                        //alpha
                        if simd_length(surfaces[s].gridPos[i][j] - surfaces[s].gridPos[i1][j]) > maxWidth { //maxWidth grid axis??
                            splitFlag = true
                        }

                        //beta
                        if i2 != -1 && surfaces[s].valid[i_1][j] && surfaces[s].valid[i][j] && surfaces[s].valid[i1][j] &&
                            Curv(u: surfaces[s].gridPos[i_1][j], v: surfaces[s].gridPos[i][j], w: surfaces[s].gridPos[i1][j])
                            + Curv(u: surfaces[s].gridPos[i][j], v: surfaces[s].gridPos[i1][j], w: surfaces[s].gridPos[i2][j]) > beta {
                            splitFlag = true
                        }

                        if !splitFlag {
                            i_1 = i
                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }

                        if i == 0 || i2 == -1
                        {
                            surfaces[s].gridPos[i_new][j] = (surfaces[s].gridPos[i][j] + surfaces[s].gridPos[i1][j]) / 2.0
                            //Simulation.Instance.no_stick(ref surfaces[s].gridPos[i_new][j])
                            //stick!!
                        }
                        else
                        {
                            surfaces[s].gridPos[i_new][j] = simd_float3(surfaces[s].gridPos[i][j] + surfaces[s].gridPos[i1][j]) * 9.0 / 16.0
                                                            - simd_float3(surfaces[s].gridPos[i_1][j] + surfaces[s].gridPos[i2][j]) / 16.0
                            //Simulation.Instance.no_stick(ref surfaces[s].gridPos[i_new][j])
                            //stick!!
                        }
                        let d1:Float = simd_length(surfaces[s].gridPos[i][j] - surfaces[s].gridPos[i_new][j])
                        let d2:Float = simd_length(surfaces[s].gridPos[i_new][j] - surfaces[s].gridPos[i1][j])

                        surfaces[s].areaZero[i_new] = surfaces[s].areaZero[i] * d1 / (d1 + d2)
                        surfaces[s].areaZero[i] = surfaces[s].areaZero[i] - surfaces[s].areaZero[i_new]

                        surfaces[s].nextIdx[i][j] = i_new
                        surfaces[s].pred[i_new][j] = i1
                        surfaces[s].valid[i_new][j] = true
                        surfaces[s].nextIdx[i_new][j] = i1

                        i_1 = i
                        i = i1
                        i1 = surfaces[s].nextIdx[i1][j]
                    }
                    //splitting end

                    //merge
                    i_1 = 0;
                    i = surfaces[s].nextIdx[0][j]

                    if i == -1 {
                        continue
                    }

                    i1 = surfaces[s].nextIdx[i][j]

                    while i1 != -1
                    {
                        let i2 = surfaces[s].nextIdx[i1][j]

                        if i2 == -1 {
                            break
                        }
                        if !surfaces[s].valid[i_1][j] || !surfaces[s].valid[i][j] || !surfaces[s].valid[i1][j]
                        {
                            i_1 = i
                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }

                        var mergeFlag:Bool = false
                        let sumArea:Float = surfaces[s].areaZero[i_1] + surfaces[s].areaZero[i]

                        //delta and zeta
                        if simd_length(surfaces[s].gridPos[i_1][j] - surfaces[s].gridPos[i][j]) + simd_length(surfaces[s].gridPos[i1][j] - surfaces[s].gridPos[i][j]) < 2 * minWidth {
                        //    if (Curv(surfaces[s].gridPos[i_1, j], surfaces[s].gridPos[i, j], surfaces[s].gridPos[i1, j]) < zeta)
                                mergeFlag = true
                        }

                        if !mergeFlag
                        {
                            i_1 = i
                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }

                        var pre:Int = surfaces[s].pred[i][j]
                        while surfaces[s].succ[pre][j - 1] == i
                        {
                            surfaces[s].succ[pre][j - 1] = i_1
                            pre = surfaces[s].nextIdx[pre][j - 1]
                        }

                        surfaces[s].areaZero[i_1] = sumArea
                        surfaces[s].areaZero[i] = 0

                        surfaces[s].valid[i][j] = false
                        surfaces[s].nextIdx[i_1][j] = i1

                        i = i1
                        i1 = surfaces[s].nextIdx[i1][j]
                    }
                    //merge end

                    //validity check
                    i = 0
                    i1 = surfaces[s].nextIdx[0][j]
                    while i1 != -1
                    {
                        let _i:Int = surfaces[s].pred[i][j]
                        let _i1:Int = surfaces[s].pred[i1][j]

                        surfaces[s].opacity[i][j] = 0

                        if _i == _i1
                        {
                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }
                        if !surfaces[s].valid[i][j]
                        {
                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }

                        if modelAC.currentACModel == "ceiling"
                        {   //prevents curling

                            let D:simd_float3 = surfaces[s].gridPos[_i][j - 1] - pos
                            let V:simd_float3 = surfaces[s].gridPos[i][j] - surfaces[s].gridPos[_i][j - 1]
                            let DD:Float = simd_length(D)
                            if DD < 15
                            {
                                if simd_dot(D, V) / (DD * simd_length(V)) < 0
                                {
                                    surfaces[s].valid[i][j] = false
                                }
                            }
                        }
                        i = i1
                        i1 = surfaces[s].nextIdx[i1][j]
                    }
                    surfaces[s].opacity[i][j] = 0

//                    validity check end

                    //opacity
                    //can use this instead of hash
                    //float[] phases = { 0.1f, 6.2f, 4.3f, 9.4f, 4.5f, 5.6f, 2.7f, 6.8f, 0.9f, 2.0f, 8.1f, 4.2f, 8.3f, 1.4f, 5.5f, 7.6f, 2.7f };
//                    i = 0
//                    while i != -1
//                    {
//                        surfaces[s].opacity[i][j] = 1.0
//                        i = surfaces[s].nextIdx[i][j]
//                    }
                    i = 0
                    i1 = surfaces[s].nextIdx[0][j]
                    while i1 != -1
                    {
                        if (!surfaces[s].valid[i][j])
                        {
                            if j == 1
                            {
                                surfaces[s].opacity[surfaces[s].pred[i][j]][0] = surfaces[s].opacity[i][j]
                            }

                            i = i1
                            i1 = surfaces[s].nextIdx[i1][j]
                            continue
                        }

                        let area:Float = simd_length(surfaces[s].gridPos[i1][j] - surfaces[s].gridPos[i][j])
                        let areaZero:Float = surfaces[s].areaZero[i]

                        var opacity:Float = 0

                        //stretch based opacity
                        if (area <= 1e-9) {
                            opacity = 1.0
                        }
                        else
                        {
                            opacity = areaZero / area
                            if opacity > 1 {
                                opacity = 1
                            }
                        }
                        
                        //fade
                        var afade:Float = ((Float(stLen) - 0.45 * Float(j)) / Float(stLen))

                        if j>280{
                            afade += Float(300-j)*0.01
                        }
                        else if j>260{
                            afade += Float(j-260)*0.01
                        }
                        
                        if j>270{
                            afade *= Float(300-j)/30.0
                        }
                        
                        opacity *= afade
                        //opacity *= ((Float(stLen) - 0.45 * Float(j)) / Float(stLen))
                        
                        //boundary
                        if i<10{
                            opacity *= Float(i) / 10.0
                        }
                        else if i>54{
                            opacity *= (64.0-Float(i))/10.0
                        }


                        //animation
                        let timerAnim:Float = Float(Int(surfaceTimer * animationSpeed) % 500) / 5.0
                        let hash:Float = Float(HashBig(x: Int(i / animationThickness), n: 100))
                        var p:Float = 25.0 * Float(s) + timerAnim - hash - Float((j % 10000) / 100)
                        //float p = 2.5f * s + (((int)(timer * 200)) % 500 / 50.0f) - HashBig(i/4,100)/10.0f - (j % 10000) / 1000.0f;
                        while (p < 0) {
                            p += 100
                        }
                        while (p >= 100) {
                            p -= 100
                        }

                        //opacity *= p < 10.0 ? 1 + (10 - p) * 0.05 : 1.0
                        //opacity = 0.7
                        
                        //opacity conversion from edge to vertex
                        if surfaces[s].opacity[i][j] == 0 {
                            surfaces[s].opacity[i][j] = opacity
                        }
                        else {
                            surfaces[s].opacity[i][j] = (surfaces[s].opacity[i][j] + opacity) / 2
                        }

                        surfaces[s].opacity[i1][j] = opacity

                        if j == 1 {
                            surfaces[s].opacity[surfaces[s].pred[i][j]][0] = surfaces[s].opacity[i][j]
                        }

                        i = i1
                        i1 = surfaces[s].nextIdx[i1][j]
                    }

                    if j == 1 {
                        surfaces[s].opacity[surfaces[s].pred[i][j]][0] = surfaces[s].opacity[i][j]
                    }
                    //opacity end
                }
            }

            AssignMeshIndex()
        }
    }
    
    func AssignMeshIndex()
    {
        surfaceVerticesIndex = 0
        surfaceVerticesCount = surfaceCnt * maxNodeCnt * stLen
        let isCeiling = modelAC.currentACModel == "ceiling"
        //assign vertices position, color
        for s in 0 ..< surfaceCnt
        {
            for j in 0 ..< stLen
            {
                var i:Int = 0
                while i != -1
                {
                    
                    //+1 on y_axis to stick to the ceiling
                    surfaceVertices[Int(SurfacePointIdx(s: s, i: i, j: j))] = surfaces[s].gridPos[i][j] + (isCeiling ? simd_float3(0,0.15,0) : simd_float3.zero)
                    textureColor.w = surfaces[s].opacity[i][j] * 1.25
                    if surfaces[s].occlude[i][j] == true {
                        textureColor.w = 0
                        surfaces[s].occlude[i][j] = false
                    }
                    surfaceColors[Int(SurfacePointIdx(s: s, i: i, j: j))] = textureColor
                    i = surfaces[s].nextIdx[i][j]
                }
            }
        }

        //assign mesh connectivity
        for s in 0 ..< surfaceCnt
        {
            for j in 0 ..< stLen
            {
                var i:Int = 0
                var i1:Int = surfaces[s].nextIdx[i][j]
                while i1 != -1
                {
                    //int _i = surfaces[s].pred[i][j]
                    let _i1:Int = surfaces[s].pred[i1][j]
                    let i_:Int = surfaces[s].succ[i][j]

                    //backward triangle
                    if surfaces[s].valid[i][j] && j != 0
                    {
                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i, j: j)
                        surfaceVerticesIndex += 1
                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i1, j: j)
                        surfaceVerticesIndex += 1
                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: _i1, j: j - 1)
                        surfaceVerticesIndex += 1
                    }
                    //forward triangle
                    if surfaces[s].valid[i][j] && j != stLen - 1 && surfaces[s].valid[i_][j + 1]
                    {
                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i, j: j)
                        surfaceVerticesIndex += 1
                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i_, j: j + 1)
                        surfaceVerticesIndex += 1
                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i1, j: j)
                        surfaceVerticesIndex += 1
                    }

                    //smoothing triangles
                    if (!surfaces[s].valid[i][j] && j != 0 && surfaces[s].valid[i1][j])
                    {
                        let _i:Int = surfaces[s].pred[i][j]
                        if(surfaces[s].valid[_i][j-1])
                        {
                            var i2:Int = i1
                            var jj:Int = j
                            
                            if jj != stLen - 1
                            {
                                var i3:Int = surfaces[s].succ[i2][jj]
                                while jj != stLen - 1 && surfaces[s].valid[i3][jj + 1]
                                {
                                    surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: _i, j: j - 1)
                                    surfaceVerticesIndex += 1
                                    surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i2, j: jj)
                                    surfaceVerticesIndex += 1
                                    surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i3, j: jj + 1)
                                    surfaceVerticesIndex += 1
                                    
                                    i2 = i3
                                    jj += 1
                                    i3 = surfaces[s].succ[i3][jj]
                                }
                            }
                        }
                    }
                    if surfaces[s].valid[i][j] && j != 0 && !surfaces[s].valid[i1][j]
                    {
                        if (j == stLen - 1 || !surfaces[s].valid[i_][j + 1])
                        {
                            var i0:Int = i1
                            var jj:Int = j
                            while jj >= 0 && !surfaces[s].valid[i1][jj]
                            {
                                i0 = surfaces[s].pred[i0][jj]
                                jj -= 1
                            }

                            if jj >= 0 && j - jj < 5
                            {
                                i0 = surfaces[s].nextIdx[i0][jj]

                                if i0 != -1
                                {
                                    let idx:UInt32 = SurfacePointIdx(s: s, i: i0, j: jj)
                                    var i2:Int = i1
                                    jj = j
                                    var i3:Int = surfaces[s].pred[i2][jj]
                                    while jj > 0 && !surfaces[s].valid[i2][jj]
                                    {
                                        surfaceIndices[surfaceVerticesIndex] = idx;
                                        surfaceVerticesIndex += 1
                                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i3, j: jj - 1);
                                        surfaceVerticesIndex += 1
                                        surfaceIndices[surfaceVerticesIndex] = SurfacePointIdx(s: s, i: i2, j: jj);
                                        surfaceVerticesIndex += 1
                                        
                                        i2 = i3
                                        jj -= 1
                                        i3 = surfaces[s].pred[i3][jj]
                                    }
                                }
                            }
                        }
                    }
                    
                    i = i1
                    i1 = surfaces[s].nextIdx[i1][j]
                }
            }
        }
    }
    
    func Curv(u:simd_float3, v:simd_float3, w:simd_float3) -> Float
    {
        return ((simd_dot(u - v, w - v) / (simd_length(u - v) * simd_length(w - v))) + 1) / 2.0
    }
    
    func HashBig(x:Int, n:Int) -> Int
    {
        //Be careful! 64bit variable
        var A:CLong = x * 73856093
        let B:CLong = x * 19349663
        let C:CLong = x * 83492791
        A = A ^ B ^ C
        var r:Int = Int(A % n)
        if r < 0 {
            r += n
        }
        return r
    }
    
    // MARK: - Occupancy grid Visualization
    
    func calculateOccupancyGridVisualizationMetal(){
        let cellLengthX = gd.gridLengthX/Float(gridSizeX)
        let cellLengthY = gd.gridLengthY/Float(gridSizeY)
        let cellLengthZ = gd.gridLengthZ/Float(gridSizeZ)
        for i in 0 ..< gridSizeX {
            for j in 0 ..< gridSizeY {
                for k in 0 ..< gridSizeZ {
                    let idx = convert3DIndex(i, j, k).0
                    if boolGrid[idx] == true && i != gridSizeX-1 && i != 0 && j != gridSizeY-1 && j != 0 && k != gridSizeZ-1 && k != 0 {
                        let position = simd_float3(Float(cos(-rotationValue)) * gridArray[idx].position.x + Float(sin(-rotationValue)) * gridArray[idx].position.z, gridArray[idx].position.y, Float(-sin(-rotationValue)) * gridArray[idx].position.x + Float(cos(-rotationValue)) * gridArray[idx].position.z)
                        
                        let rotation = float4x4(simd_quatf(angle: -rotationValue, axis: simd_float3(0,1,0)))
                        
                        let scale = float4x4(scaling: simd_float3(cellLengthX/0.375, cellLengthY/0.375, cellLengthZ/0.375))
                        let color = simd_float4(1,1,0,0.8)
                        let newGridCell = objNode(name: "grid", position: position, rotation: rotation, scale: scale, color: color)
                        gridNodeArr.append(newGridCell)
                    }
                }
            }
        }
        //print(gridNodeArr, gridSizeX, gridSizeY, gridSizeZ)
        gridInstance.updateModelConstant(objNodes: gridNodeArr)
        gridNotReady = false
    }
    
     func updateOccupancyGridVisualizationMetal(location: CGPoint) -> simd_float3? {
         guard let currentFrame = sceneView.session.currentFrame else { return nil }
         updateCamera(frame: currentFrame)
         let camera = currentFrame.camera
         
         let viewMatrix = camera.viewMatrix(for: orientation)
         let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewPortSize, zNear: 0.01, zFar: 0.0)
         let inverseProjection = projectionMatrix.inverse
         
         let clipX = (2*Float(location.x)) / Float(viewPortSize.width) - 1
         let clipY = 1 - (2*Float(location.y)) / Float(viewPortSize.height)
         let clipCoords = simd_float4(clipX, clipY, 0, 1)
         
         var eyeRayDir = inverseProjection * clipCoords
         eyeRayDir.z = -1
         eyeRayDir.w = 0
         
         var worldRayDir = (viewMatrix.inverse * eyeRayDir).xyz
         worldRayDir = normalize(worldRayDir)
         let worldRayOrigin = (viewMatrix.inverse * simd_float4(0,0,0,1)).xyz
         let ray = Ray(origin: worldRayOrigin, direction: worldRayDir)
         
         
         var closestNodeDist: Float!
         var removePos: simd_float3!
         var removeId: UUID!
         var removeIdx: Int!
         
         for node_ in gridNodeArr {
             if let nodePos = node_.hitTest(ray){
                 if node_.hit {
                     continue
                 }
                 else if closestNodeDist == nil {
                     removeId = node_.identifier
                     closestNodeDist = distance(gd.eye, nodePos)
                 }
                 else if distance(gd.eye, nodePos) < closestNodeDist {
                     removeId = node_.identifier
                     closestNodeDist = distance(gd.eye, nodePos)
                 }
             }
         }
         
         if removeId == nil {
             return nil
         }
         else {
             for i in 0..<gridNodeArr.count {
                 if gridNodeArr[i].identifier == removeId {
                     removePos = gridNodeArr[i].position
                     removeIdx = i
                     break
                 }
             }
             gridNodeArr.remove(at: removeIdx)
             gridInstance.updateModelConstant(objNodes: gridNodeArr)
             return removePos
         }
     }
     
    /*
    // whenever there is a touch
    func updateOccupancyGridVisualizationMetal(location: CGPoint) -> simd_float3? {
        guard let currentFrame = sceneView.session.currentFrame else { return nil }
        updateCamera(frame: currentFrame)
        let camera = currentFrame.camera
        
        let viewMatrix = camera.viewMatrix(for: orientation)
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewPortSize, zNear: 0.01, zFar: 0.0)
        let inverseProjection = projectionMatrix.inverse
        
        let clipX = (2*Float(location.x)) / Float(viewPortSize.width) - 1
        let clipY = 1 - (2*Float(location.y)) / Float(viewPortSize.height)
        let clipCoords = simd_float4(clipX, clipY, 0, 1)
        
        var eyeRayDir = inverseProjection * clipCoords
        eyeRayDir.z = -1
        eyeRayDir.w = 0
        
        var worldRayDir = (viewMatrix.inverse * eyeRayDir).xyz
        worldRayDir = normalize(worldRayDir)
        let worldRayOrigin = (viewMatrix.inverse * simd_float4(0,0,0,1)).xyz
        let ray = Ray(origin: worldRayOrigin, direction: worldRayDir)
        
        
        var closestNodeDist: Float!
        var removePos: simd_float3!
        var removeId: UUID!
        var removeIdx: Int!
        
        for node_ in gridNodeArr {
            if let nodePos = node_.hitTest(ray){
                if node_.hit {
                    continue
                }
                else if closestNodeDist == nil {
                    removeId = node_.identifier
                    closestNodeDist = distance(gd.eye, nodePos)
                }
                else if distance(gd.eye, nodePos) < closestNodeDist {
                    removeId = node_.identifier
                    closestNodeDist = distance(gd.eye, nodePos)
                }
            }
        }
        
        if removeId == nil {
            return nil
        }
        else {
            for i in 0..<gridNodeArr.count {
                if gridNodeArr[i].identifier == removeId {
                    removePos = gridNodeArr[i].position
                    removeIdx = i
                    break
                }
            }
            gridNodeArr.remove(at: removeIdx)
            gridInstance.updateModelConstant(objNodes: gridNodeArr)
            return removePos
        }
    }
     */


    // MARK: - Visualization continuous update
    
    func startVisualization(){
        if currentVisualization == "Vector" {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(vectorVisualizationRepeat))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .current, forMode: .common)
        }
        else if currentVisualization == "Volume" {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(volumeVisualizationRepeat))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .current, forMode: .common)
        }
        else if currentVisualization == "Particle" {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(particleVisualizationRepeat))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .current, forMode: .common)
        }
        else if currentVisualization == "Dense Particle" {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(denseParticleVisualizationRepeat))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .current, forMode: .common)
        }
        else if currentVisualization == "Flow and Volume" {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(vectorVolumeVisualizationRepeat))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .current, forMode: .common)
        }
        else if currentVisualization == "Pinpoint" {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(pinPointVisualizationRepeat))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .current, forMode: .common)
        }
        else if currentVisualization == "Surface" {
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(surfaceVisualizationRepeat))
            displayLink?.preferredFramesPerSecond = 60
            displayLink?.add(to: .current, forMode: .common)
        }
    }
    
    @objc func pinPointVisualizationRepeat(){
        guard let currentFrame = sceneView.session.currentFrame else { return }
        let camera = currentFrame.camera
        let view_matrix = camera.viewMatrix(for: orientation).transpose.inverse
        eye = simd_float3(view_matrix[0,3], view_matrix[1,3], view_matrix[2,3])
        cameraToPoint = distance(eye, simd_float3(graph.graphRootNode.position))
    }
    
    @objc func vectorVisualizationRepeat() {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        get_server_data()
        updateArrow(currentFrame: currentFrame, arrow_speed: 2.0)
    }
    
    @objc func volumeVisualizationRepeat(){
        var temp: [primVert] = []
        get_server_data()
        updatePlaneLocation()
        gpuCompute.updateBuffers()
        
        let gpuRes = gpuCompute.gpu_get_plane_vertex(device: device, commandQueue: sceneView.commandQueue!, planePos: planeUniforms)
        let newTemp = gpuCompute.gpu_interpolate(device: device, commandQueue: sceneView.commandQueue!, verticies: gpuRes.0).0
        
        for i in 0..<gpuRes.0.count {
            var newColor = getTemperatureColor(interpolated_temp: newTemp[i].x)
            if newTemp[i].y == 0.0 && complete_occlude{
                newColor.w = newTemp[i].y
            }
            
            let rotPosition = simd_float3(Float(cos(rotationValue)) * gpuRes.0[i].x + Float(sin(rotationValue)) * gpuRes.0[i].z,
                                          gpuRes.0[i].y,
                                            -Float(sin(rotationValue)) * gpuRes.0[i].x + Float(cos(rotationValue)) * gpuRes.0[i].z)
            
            if rotPosition.x >= boundary_points[0] || rotPosition.x <= boundary_points[1] || rotPosition.y >= pc_max_y || rotPosition.y <= pc_min_y || rotPosition.z >= boundary_points[2] || rotPosition.z <= boundary_points[3] {
                newColor.w = 0.0
            }
            let newVert = primVert(position: gpuRes.0[i], normal: simd_float3(0,0,0), color: newColor)
            temp.append(newVert)
        }
        volumePlane.verticies = temp
        volumePlane.indicies = gpuRes.1

    }
    
    @objc func vectorVolumeVisualizationRepeat(){
        guard let currentFrame = sceneView.session.currentFrame else { return }
        get_server_data()
        
        // arrow
        updateArrow(currentFrame: currentFrame, arrow_speed: 2.0)
        
        // volume
        updatePlaneLocation()
        gpuCompute.updateBuffers()
        var temp: [primVert] = []
        let gpuRes = gpuCompute.gpu_get_plane_vertex(device: device, commandQueue: sceneView.commandQueue!, planePos: planeUniforms)
        let newTemp = gpuCompute.gpu_interpolate(device: device, commandQueue: sceneView.commandQueue!, verticies: gpuRes.0).0
        
        for i in 0..<gpuRes.0.count {
            var newColor = getTemperatureColor(interpolated_temp: newTemp[i].x)
            if newTemp[i].y == 0.0 && complete_occlude{
                newColor.w = newTemp[i].y
            }
            
            let rotPosition = simd_float3(Float(cos(rotationValue)) * gpuRes.0[i].x + Float(sin(rotationValue)) * gpuRes.0[i].z,
                                          gpuRes.0[i].y,
                                            -Float(sin(rotationValue)) * gpuRes.0[i].x + Float(cos(rotationValue)) * gpuRes.0[i].z)
            
            if rotPosition.x >= boundary_points[0] || rotPosition.x <= boundary_points[1] || rotPosition.y >= pc_max_y || rotPosition.y <= pc_min_y || rotPosition.z >= boundary_points[2] || rotPosition.z <= boundary_points[3] {
                newColor.w = 0.0
            }
            let newVert = primVert(position: gpuRes.0[i], normal: simd_float3(0,0,0), color: newColor)
            temp.append(newVert)
        }
        volumePlane.verticies = temp
        volumePlane.indicies = gpuRes.1
    }
    
    @objc func particleVisualizationRepeat(){
        guard let currentFrame = self.sceneView.session.currentFrame else { return }
        get_server_data()
        updateParticleVane(currentFrame: currentFrame)
    }
    
    @objc func denseParticleVisualizationRepeat(){
        guard let currentFrame = sceneView.session.currentFrame else { return }
        get_server_data()
        updateParticle(currentFrame: currentFrame)
    }
    
    @objc func surfaceVisualizationRepeat(){
        if surfaceStarted {
            //guard let currentFrame = sceneView.session.currentFrame else { return }
            get_server_data()
            
            // surface
            gpuCompute.updateBuffers()
            var surfaceTemp: [primVert] = []
            var surfaceTempIndicies: [UInt32] = []
            var lineTemp: [primVert] = []
            var lineTempIndicies: [UInt32] = []
            //let gpuRes = gpuCompute.gpu_get_plane_vertex(device: device, commandQueue: sceneView.commandQueue!, planePos: planeUniforms)
            //let newTemp = gpuCompute.gpu_interpolate(device: device, commandQueue: sceneView.commandQueue!, verticies: gpuRes.0).0
            updateSurface()
            updateLines()
            
            let tempVerticesCount = surfaceVerticesCount > lineVerticesCount ? surfaceVerticesCount : lineVerticesCount
            let tempIndicesCount = surfaceVerticesIndex > lineVerticesIndex ? surfaceVerticesIndex : lineVerticesIndex
            
            for i in 0 ..< tempVerticesCount {
                if i < surfaceVerticesCount {
                    var newColor = surfaceColors[i]
        //            if newTemp[i].y == 0.0 && complete_occlude{
        //                newColor.w = newTemp[i].y
        //            }
                    
                    let rotPosition = simd_float3(Float(cos(rotationValue)) * surfaceVertices[i].x + Float(sin(rotationValue)) * surfaceVertices[i].z,
                                                  surfaceVertices[i].y,
                                                    -Float(sin(rotationValue)) * surfaceVertices[i].x + Float(cos(rotationValue)) * surfaceVertices[i].z)
                    
                    if rotPosition.x >= boundary_points[0] || rotPosition.x <= boundary_points[1] || rotPosition.y >= pc_max_y || rotPosition.y <= pc_min_y || rotPosition.z >= boundary_points[2] || rotPosition.z <= boundary_points[3] {
                        newColor.w = 0.0
                    }
                    let newVert = primVert(position: surfaceVertices[i], normal: simd_float3(0,0,0), color: newColor)
                    surfaceTemp.append(newVert)
                }
                
                if i < lineVerticesCount {
                    var newColor = lineVerticesColors[i]
        //            if newTemp[i].y == 0.0 && complete_occlude{
        //                newColor.w = newTemp[i].y
        //            }
                    
                    let rotPosition = simd_float3(Float(cos(rotationValue)) * lineVertices[i].x + Float(sin(rotationValue)) * lineVertices[i].z,
                                                  lineVertices[i].y,
                                                    -Float(sin(rotationValue)) * lineVertices[i].x + Float(cos(rotationValue)) * lineVertices[i].z)
                    
                    if rotPosition.x >= boundary_points[0] || rotPosition.x <= boundary_points[1] || rotPosition.y >= pc_max_y || rotPosition.y <= pc_min_y || rotPosition.z >= boundary_points[2] || rotPosition.z <= boundary_points[3] {
                        newColor.w = 0.0
                    }
                    let newVert = primVert(position: lineVertices[i], normal: simd_float3(0,0,0), color: newColor)
                    lineTemp.append(newVert)
                }
            }
            
            for i in 0 ..< tempIndicesCount {
                if i < surfaceVerticesIndex {
                    surfaceTempIndicies.append(surfaceIndices[i])
                }
                if i < lineVerticesIndex {
                    lineTempIndicies.append(lineIndices[i])
                }
            }
            
            surfaceModel.verticies = surfaceTemp
            surfaceModel.indicies = surfaceTempIndicies
            
            lineModel.verticies = lineTemp
            lineModel.indicies = lineTempIndicies
            
//            // lines
//            temp = []
//            tempIndicies = []
//
//            updateLines()
//
//            for i in 0 ..< lineVerticesCount {
//                var newColor = lineVerticesColors[i]
//    //            if newTemp[i].y == 0.0 && complete_occlude{
//    //                newColor.w = newTemp[i].y
//    //            }
//
//                let rotPosition = simd_float3(Float(cos(rotationValue)) * lineVertices[i].x + Float(sin(rotationValue)) * lineVertices[i].z,
//                                              lineVertices[i].y,
//                                                -Float(sin(rotationValue)) * lineVertices[i].x + Float(cos(rotationValue)) * lineVertices[i].z)
//
//                if rotPosition.x >= boundary_points[0] || rotPosition.x <= boundary_points[1] || rotPosition.y >= pc_max_y || rotPosition.y <= pc_min_y || rotPosition.z >= boundary_points[2] || rotPosition.z <= boundary_points[3] {
//                    newColor.w = 0.0
//                }
//                let newVert = primVert(position: lineVertices[i], normal: simd_float3(0,0,0), color: newColor)
//                temp.append(newVert)
//            }
//            for i in 0 ..< lineVerticesIndex {
//                tempIndicies.append(lineIndices[i])
//            }
//            lineModel.verticies = temp
//            lineModel.indicies = tempIndicies
        }
    }
    // MARK: - Render functions

    func renderOccupancyGrid(commandEncoder: MTLRenderCommandEncoder){
        if gridNotReady {
            return
        }
        guard let currentFrame = sceneView.session.currentFrame else { return }
        if gridNodeArr.count == 0 {
            return
        }
        updateCamera(frame: currentFrame)
        var enableLight: Int = 1
        
        commandEncoder.setRenderPipelineState(instancedPipeline)
        commandEncoder.setDepthStencilState(objDepthStencilState)
        commandEncoder.setVertexBytes(&cameraUniform, length: MemoryLayout<CameraUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&eye, length: MemoryLayout<simd_float3>.stride, index: 3)
        commandEncoder.setVertexBuffer(gridInstance.modelConstantsBuffer, offset: 0, index: 2)
        
        commandEncoder.setFragmentSamplerState(textureSamplerState, index: 0)
        commandEncoder.setFragmentTexture(globalLightingCubeMap, index: 10)
        commandEncoder.setFragmentBytes(&globalLight, length: MemoryLayout<lightUniform>.stride, index: 11)
        commandEncoder.setFragmentBytes(&enableLight, length: MemoryLayout<Int>.stride, index: 12)
        gridInstance.render(renderEncoder: commandEncoder, useMaterial: false)
    }
        
    func renderArrows(commandEncoder: MTLRenderCommandEncoder) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        let temp = arrowNodeArr
        if temp.count == 0 {
            return 
        }
        updateCamera(frame: currentFrame)
        arrowInstance.updateModelConstant(objNodes: temp)
        var enableLight: Int = 1
        
        commandEncoder.setRenderPipelineState(instancedPipeline)
        commandEncoder.setDepthStencilState(objDepthStencilState)
        commandEncoder.setVertexBytes(&cameraUniform, length: MemoryLayout<CameraUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&eye, length: MemoryLayout<simd_float3>.stride, index: 3)
        commandEncoder.setVertexBuffer(arrowInstance.modelConstantsBuffer, offset: 0, index: 2)
        
        commandEncoder.setFragmentSamplerState(textureSamplerState, index: 0)
        commandEncoder.setFragmentTexture(globalLightingCubeMap, index: 10)
        commandEncoder.setFragmentBytes(&globalLight, length: MemoryLayout<lightUniform>.stride, index: 11)
        commandEncoder.setFragmentBytes(&enableLight, length: MemoryLayout<Int>.stride, index: 12)
        arrowInstance.render(renderEncoder: commandEncoder, useMaterial: false)
    }
    
    func renderParticles(commandEncoder: MTLRenderCommandEncoder) {
        if bufferNode.count == 0 {
            return
        }
        Particle.updateBufferContents(updatedVerticies: bufferNode)
        
        commandEncoder.setRenderPipelineState(particlePipeline)
        commandEncoder.setDepthStencilState(objDepthStencilState)
        commandEncoder.setVertexBuffer(Particle.verticiesBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(&cameraUniform, length: MemoryLayout<CameraUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&Particle.modelMat, length: MemoryLayout<simd_float4x4>.stride, index: 2)
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: Particle.verticiesCount)
        
    }
    
    func renderDenseParticles(commandEncoder: MTLRenderCommandEncoder) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        updateCamera(frame: currentFrame)
        
        if bufferNode.count == 0 {
            return
        }
        Particle.updateBufferContents(updatedVerticies: bufferNode)
        
        commandEncoder.setRenderPipelineState(particlePipeline)
        commandEncoder.setDepthStencilState(objDepthStencilState)
        commandEncoder.setVertexBuffer(Particle.verticiesBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(&cameraUniform, length: MemoryLayout<CameraUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&Particle.modelMat, length: MemoryLayout<simd_float4x4>.stride, index: 2)
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: Particle.verticiesCount)

    }
    
    func renderVolume(commandEncoder: MTLRenderCommandEncoder){
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        let verticies = volumePlane.verticies; let indicies = volumePlane.indicies
        if verticies.count == 0 || indicies.count == 0 {
            return
        }
        updateCamera(frame: currentFrame)
        volumePlane.updateBufferContents(updatedVerticies: verticies)
        volumePlane.updateIndexBufferContents(updatedIndicies: indicies)
        var enableLight: Int = 0

        commandEncoder.setRenderPipelineState(primitiveVolumePipeline)
        commandEncoder.setDepthStencilState(objDepthStencilState)
        commandEncoder.setVertexBuffer(volumePlane.verticiesBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(&cameraUniform, length: MemoryLayout<CameraUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&volumePlane.modelMat, length: MemoryLayout<simd_float4x4>.stride, index: 2)
        commandEncoder.setVertexBytes(&eye, length: MemoryLayout<simd_float3>.stride, index: 3)
        
        commandEncoder.setFragmentBytes(&globalLight, length: MemoryLayout<lightUniform>.stride, index: 1)
        commandEncoder.setFragmentBytes(&enableLight, length: MemoryLayout<Int>.stride, index: 2)
        commandEncoder.drawIndexedPrimitives(type: .triangle,
                                             indexCount: volumePlane.indexCount,
                                             indexType: volumePlane.indexType,
                                             indexBuffer: volumePlane.indexBuffer,
                                             indexBufferOffset: 0)
    }
    
    func renderSurface(commandEncoder: MTLRenderCommandEncoder){
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        let verticies = surfaceModel.verticies; let indicies = surfaceModel.indicies
        if verticies.count == 0 || indicies.count == 0 {
            return
        }
        updateCamera(frame: currentFrame)
        surfaceModel.updateBufferContents(updatedVerticies: verticies)
        surfaceModel.updateIndexBufferContents(updatedIndicies: indicies)
        var enableLight: Int = 0
        
        commandEncoder.setCullMode(MTLCullMode.none)
        commandEncoder.setRenderPipelineState(primitivePipeline)
        commandEncoder.setDepthStencilState(objDepthStencilState)
        commandEncoder.setVertexBuffer(surfaceModel.verticiesBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(&cameraUniform, length: MemoryLayout<CameraUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&surfaceModel.modelMat, length: MemoryLayout<simd_float4x4>.stride, index: 2)
        commandEncoder.setVertexBytes(&eye, length: MemoryLayout<simd_float3>.stride, index: 3)
        
        commandEncoder.setFragmentBytes(&globalLight, length: MemoryLayout<lightUniform>.stride, index: 1)
        commandEncoder.setFragmentBytes(&enableLight, length: MemoryLayout<Int>.stride, index: 2)
        commandEncoder.drawIndexedPrimitives(type: .triangle,
                                             indexCount: surfaceModel.indexCount,
                                             indexType: surfaceModel.indexType,
                                             indexBuffer: surfaceModel.indexBuffer,
                                             indexBufferOffset: 0)
    }
    
    func renderLine(commandEncoder: MTLRenderCommandEncoder){
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        let verticies = lineModel.verticies; let indicies = lineModel.indicies
        if verticies.count == 0 || indicies.count == 0 {
            return
        }
        updateCamera(frame: currentFrame)
        lineModel.updateBufferContents(updatedVerticies: verticies)
        lineModel.updateIndexBufferContents(updatedIndicies: indicies)
        var enableLight: Int = 0
        
        commandEncoder.setCullMode(MTLCullMode.none)
        commandEncoder.setRenderPipelineState(primitivePipeline)
        commandEncoder.setDepthStencilState(objDepthStencilState)
        commandEncoder.setVertexBuffer(lineModel.verticiesBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(&cameraUniform, length: MemoryLayout<CameraUniforms>.stride, index: 1)
        commandEncoder.setVertexBytes(&lineModel.modelMat, length: MemoryLayout<simd_float4x4>.stride, index: 2)
        commandEncoder.setVertexBytes(&eye, length: MemoryLayout<simd_float3>.stride, index: 3)
        
        commandEncoder.setFragmentBytes(&globalLight, length: MemoryLayout<lightUniform>.stride, index: 1)
        commandEncoder.setFragmentBytes(&enableLight, length: MemoryLayout<Int>.stride, index: 2)
        commandEncoder.drawIndexedPrimitives(type: .triangle,
                                             indexCount: lineModel.indexCount,
                                             indexType: lineModel.indexType,
                                             indexBuffer: lineModel.indexBuffer,
                                             indexBufferOffset: 0)
    }
                
    // MARK: - Utility functions
    
    func resetVisualization(){
        displayLink?.invalidate()        
        sceneView.scene.rootNode.enumerateChildNodes{ (node, stop) in
            if node.name != "ACNode" {
                node.removeFromParentNode()
            }
        }
        bufferNode = []
        
        // reset vector visuzliation
        arrowNodeArr = []
        arrowCreated = false
        ArrowTimer = 0
        
        // volume
        //planeNodeArr = []
        
        // reset occupancy grid visualization
        gridNodeArr = []
        
        // particle
        particleNodeArr = []
        
        // surface
        surfaceVerticesCount = 0
        surfaceVerticesIndex = 0
        surfaceStarted = false
        
        //line
        //lineArray = []
        lineVerticesCount = 0
        lineVerticesIndex = 0
    }
    
    func getVelocityTemper(pos:simd_float3) -> (simd_float2, simd_float3)
    {
        var position:simd_float3 = pos
        position = simd_float3(Float(cos(rotationValue)) * position.x + Float(sin(rotationValue)) * position.z,
                          position.y,
                          -Float(sin(rotationValue)) * position.x + Float(cos(rotationValue)) * position.z)
        var newTemp:Float = 0.0
        var newVel:simd_float3 = simd_float3(0.0,0.0,0.0)

        let P1:Float = boundary_points[1]
        let P3:Float = boundary_points[3]

        guard !((Float(gd.gridSizeX)*(position.x - P1)/gd.gridLengthX).isNaN ||
                (Float(gd.gridSizeX)*(position.x - P1)/gd.gridLengthX).isInfinite ||
                (Float(gd.gridSizeY)*(position.y - gd.pc_min_y)/gd.gridLengthY).isNaN ||
                (Float(gd.gridSizeY)*(position.y - gd.pc_min_y)/gd.gridLengthY).isInfinite ||
                (Float(gd.gridSizeZ)*(position.z - P3)/gd.gridLengthZ).isNaN ||
                (Float(gd.gridSizeZ)*(position.z - P3)/gd.gridLengthZ).isInfinite) else {
            //print("null")
            return (simd_float2(1.0, 1.0), simd_float3(0.001,-0.001,0.001))
        }
        
        var ind_x:Int = Int(Float(gd.gridSizeX)*(position.x - P1)/gd.gridLengthX)
        var ind_y:Int = Int(Float(gd.gridSizeY)*(position.y - gd.pc_min_y)/gd.gridLengthY)
        var ind_z:Int = Int(Float(gd.gridSizeZ)*(position.z - P3)/gd.gridLengthZ)

        if (ind_x >= Int(gd.gridSizeX)){
            ind_x = Int(gd.gridSizeX-1)
        }
        if (ind_y >= Int(gd.gridSizeY)){
            ind_y = Int(gd.gridSizeY-1)
        }
        if (ind_z >= Int(gd.gridSizeZ)){
            ind_z = Int(gd.gridSizeZ-1)
        }
        if (ind_x < 0){
            ind_x = 0
        }
        if (ind_y < 0){
            ind_y = 0
        }
        if (ind_z < 0){
            ind_z = 0
        }

        var max_x:Float = position.x
        var min_x:Float = position.x
        var max_y:Float = position.y
        var min_y:Float = position.y
        var max_z:Float = position.z
        var min_z:Float = position.z

        var ind_max_x:Int = ind_x
        var ind_max_y:Int = ind_y
        var ind_max_z:Int = ind_z

        var ind_min_x:Int = ind_x
        var ind_min_y:Int = ind_y
        var ind_min_z:Int = ind_z

        var p1:simd_float3 = simd_float3(0,0,0)
        var p2:simd_float3 = simd_float3(0,0,0)
        var p3:simd_float3 = simd_float3(0,0,0)
        var p4:simd_float3 = simd_float3(0,0,0)
        var p5:simd_float3 = simd_float3(0,0,0)
        var p6:simd_float3 = simd_float3(0,0,0)

        var t1:Float = 0
        var t2:Float = 0
        var t3:Float = 0
        var t4:Float = 0
        var t5:Float = 0
        var t6:Float = 0

        let idx_1d:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z
        if(position.x >= gridArray[idx_1d].position.x && position.y >= gridArray[idx_1d].position.y && position.z >= gridArray[idx_1d].position.z){
            min_x = gridArray[idx_1d].position.x
            min_y = gridArray[idx_1d].position.y
            min_z = gridArray[idx_1d].position.z

            ind_min_x = Int(Float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX)
            ind_min_y = Int(Float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY)
            ind_min_z = Int(Float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ)

            if(ind_x < gd.gridSizeX - 1){
                let new_idx:Int = (ind_x+1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z
                max_x = gridArray[new_idx].position.x
                ind_max_x += 1
            }
            if(ind_y < gd.gridSizeY - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y+1) * Int(gd.gridSizeZ) + ind_z
                max_y = gridArray[new_idx].position.y
                ind_max_y += 1
            }
            if(ind_z < gd.gridSizeZ - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + (ind_z+1)
                max_z = gridArray[new_idx].position.z
                ind_max_z += 1
            }

            // 1
            var d1:Float = position.x - min_x
            var d2:Float = max_x - position.x

            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            var max_temperature:Float = temperatureData[max_indicies]
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            var min_temperature:Float = temperatureData[min_indicies]

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //5, 6
            d1 = position.z - min_z;
            d2 = max_z - position.z;


            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2));
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2));

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2));
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2));

            //new
            d1 = position.y - min_y;
            d2 = max_y - position.y;


            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2));
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2));
        }

        else if(position.x >= gridArray[idx_1d].position.x && position.y >= gridArray[idx_1d].position.y && position.z < gridArray[idx_1d].position.z){
            min_x = gridArray[idx_1d].position.x;
            min_y = gridArray[idx_1d].position.y;
            max_z = gridArray[idx_1d].position.z;

            ind_min_x = Int(Float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX);
            ind_min_y = Int(Float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY);
            ind_max_z = Int(Float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ);

            if(ind_x < gd.gridSizeX - 1){
                let new_idx:Int = (ind_x+1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z;
                max_x = gridArray[new_idx].position.x;
                ind_max_x += 1;
            }
            if(ind_y < gd.gridSizeY - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y+1) * Int(gd.gridSizeZ) + ind_z;
                max_y = gridArray[new_idx].position.y;
                ind_max_y += 1;
            }
            if(ind_z > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + (ind_z-1);
                min_z = gridArray[new_idx].position.z;
                ind_min_z -= 1;
            }

            //1
            var d1:Float = position.x - min_x;
            var d2:Float = max_x - position.x;


            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            var max_temperature:Float = temperatureData[max_indicies]
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            var min_temperature:Float = temperatureData[min_indicies]

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //5, 6
            d1 = position.z - min_z
            d2 = max_z - position.z


            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2))
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2))

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2))
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2))

            //new
            d1 = position.y - min_y
            d2 = max_y - position.y

            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2))
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2))
        }

        else if(position.x >= gridArray[idx_1d].position.x && position.y < gridArray[idx_1d].position.y && position.z >= gridArray[idx_1d].position.z){
            min_x = gridArray[idx_1d].position.x
            max_y = gridArray[idx_1d].position.y
            min_z = gridArray[idx_1d].position.z

            ind_min_x = Int(Float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX)
            ind_max_y = Int(Float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY)
            ind_min_z = Int(Float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ)

            if(ind_x < gd.gridSizeX - 1){
                let new_idx:Int = (ind_x+1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z
                max_x = gridArray[new_idx].position.x
                ind_max_x += 1
            }
            if(ind_y > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y-1) * Int(gd.gridSizeZ) + ind_z
                min_y = gridArray[new_idx].position.y
                ind_min_y -= 1
            }
            if(ind_z < gd.gridSizeZ - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + (ind_z+1)
                max_z = gridArray[new_idx].position.z
                ind_max_z += 1
            }

            //1
            var d1:Float = position.x - min_x
            var d2:Float = max_x - position.x

            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            var max_temperature:Float = temperatureData[max_indicies]
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            var min_temperature:Float = temperatureData[min_indicies]

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //5, 6
            d1 = position.z - min_z;
            d2 = max_z - position.z;

            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2));
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2));

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2));
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2));

            //new
            d1 = position.y - min_y;
            d2 = max_y - position.y;


            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2));
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2));
        }


        else if(position.x >= gridArray[idx_1d].position.x && position.y < gridArray[idx_1d].position.y && position.z < gridArray[idx_1d].position.z){
            min_x = gridArray[idx_1d].position.x;
            max_y = gridArray[idx_1d].position.y;
            max_z = gridArray[idx_1d].position.z;

            ind_min_x = Int(Float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX)
            ind_max_y = Int(Float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY)
            ind_max_z = Int(Float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ)

            if(ind_x < gd.gridSizeX - 1){
                let new_idx:Int = (ind_x+1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z
                max_x = gridArray[new_idx].position.x
                ind_max_x += 1
            }
            if(ind_y > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y-1) * Int(gd.gridSizeZ) + ind_z
                min_y = gridArray[new_idx].position.y
                ind_min_y -= 1
            }
            if(ind_z > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + (ind_z-1)
                min_z = gridArray[new_idx].position.z
                ind_min_z -= 1
            }

            //1
            var d1:Float = position.x - min_x
            var d2:Float = max_x - position.x


            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            var max_temperature:Float = temperatureData[max_indicies]
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            var min_temperature:Float = temperatureData[min_indicies]

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2])
            max_temperature = temperatureData[max_indicies]
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2])
            min_temperature = temperatureData[min_indicies]

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2))
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2))

            //5, 6
            d1 = position.z - min_z
            d2 = max_z - position.z


            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2))
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2))

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2))
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2))

            //new
            d1 = position.y - min_y;
            d2 = max_y - position.y;


            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2));
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2));
        }

        else if(position.x < gridArray[idx_1d].position.x && position.y >= gridArray[idx_1d].position.y && position.z >= gridArray[idx_1d].position.z){
            max_x = gridArray[idx_1d].position.x;
            min_y = gridArray[idx_1d].position.y;
            min_z = gridArray[idx_1d].position.z;

            ind_max_x = Int(Float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
            ind_min_y = Int(Float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY);
            ind_min_z = Int(Float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ);

            if(ind_x > 0){
                let new_idx:Int = (ind_x-1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z;
                min_x = gridArray[new_idx].position.x;
                ind_min_x -= 1;
            }
            if(ind_y < gd.gridSizeY - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y+1) * Int(gd.gridSizeZ) + ind_z;
                max_y = gridArray[new_idx].position.y;
                ind_max_y += 1;
            }
            if(ind_z < gd.gridSizeZ - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) +  (ind_z+1);
                max_z = gridArray[new_idx].position.z;
                ind_max_z += 1;
            }

            //1
            var d1:Float = position.x - min_x;
            var d2:Float = max_x - position.x;


            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            var max_temperature:Float = temperatureData[max_indicies];
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            var min_temperature:Float = temperatureData[min_indicies];

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //5, 6
            d1 = position.z - min_z;
            d2 = max_z - position.z;


            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2));
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2));

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2));
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2));
            //new
            d1 = position.y - min_y;
            d2 = max_y - position.y;

            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2));
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2));
        }

        else if(position.x < gridArray[idx_1d].position.x && position.y >= gridArray[idx_1d].position.y && position.z < gridArray[idx_1d].position.z){
            max_x = gridArray[idx_1d].position.x;
            min_y = gridArray[idx_1d].position.y;
            max_z = gridArray[idx_1d].position.z;

            ind_max_x = Int(Float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
            ind_min_y = Int(Float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY);
            ind_max_z = Int(Float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ);

            if(ind_x > 0){
                let new_idx:Int = (ind_x-1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z;
                min_x = gridArray[new_idx].position.x;
                ind_min_x -= 1;
            }
            if(ind_y < gd.gridSizeY - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y+1) * Int(gd.gridSizeZ) + ind_z;
                max_y = gridArray[new_idx].position.y;
                ind_max_y += 1;
            }
            if(ind_z > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + (ind_z-1);
                min_z = gridArray[new_idx].position.z;
                ind_min_z -= 1;
            }

            //1
            var d1:Float = position.x - min_x
            var d2:Float = max_x - position.x


            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            var max_temperature:Float = temperatureData[max_indicies];
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            var min_temperature:Float = temperatureData[min_indicies];

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //5, 6
            d1 = position.z - min_z;
            d2 = max_z - position.z;


            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2));
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2));

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2));
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2));
            //new
            d1 = position.y - min_y;
            d2 = max_y - position.y;

            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2));
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2));
        }
        else if(position.x < gridArray[idx_1d].position.x && position.y < gridArray[idx_1d].position.y && position.z >= gridArray[idx_1d].position.z){
            max_x = gridArray[idx_1d].position.x;
            max_y = gridArray[idx_1d].position.y;
            min_z = gridArray[idx_1d].position.z;

            ind_max_x = Int(Float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
            ind_max_y = Int(Float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY);
            ind_min_z = Int(Float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ);

            if(ind_x > 0){
                let new_idx:Int = (ind_x-1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z;
                min_x = gridArray[new_idx].position.x;
                ind_min_x -= 1;
            }
            if(ind_y > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y-1) * Int(gd.gridSizeZ) + ind_z;
                min_y = gridArray[new_idx].position.y;
                ind_min_y -= 1;
            }
            if(ind_z < gd.gridSizeZ - 1){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + (ind_z+1);
                max_z = gridArray[new_idx].position.z;
                ind_max_z += 1;
            }

            //1
            var d1:Float = position.x - min_x;
            var d2:Float = max_x - position.x;


            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            var max_temperature:Float = temperatureData[max_indicies];
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            var min_temperature:Float = temperatureData[min_indicies];

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //5, 6
            d1 = position.z - min_z;
            d2 = max_z - position.z;

            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2));
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2));

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2));
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2));
            //new
            d1 = position.y - min_y;
            d2 = max_y - position.y;

            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2));
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2));
        }

        else if(position.x < gridArray[idx_1d].position.x && position.y < gridArray[idx_1d].position.y && position.z < gridArray[idx_1d].position.z){
            max_x = gridArray[idx_1d].position.x;
            max_y = gridArray[idx_1d].position.y;
            max_z = gridArray[idx_1d].position.z;

            ind_max_x = Int(Float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
            ind_max_y = Int(Float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY);
            ind_max_z = Int(Float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ);

            if(ind_x > 0){
                let new_idx:Int = (ind_x-1) * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z;
                min_x = gridArray[new_idx].position.x;
                ind_min_x -= 1;
            }
            if(ind_y > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + (ind_y-1) * Int(gd.gridSizeZ) + ind_z;
                min_y = gridArray[new_idx].position.y;
                ind_min_y -= 1;
            }
            if(ind_z > 0){
                let new_idx:Int = ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + (ind_z-1);
                min_z = gridArray[new_idx].position.z;
                ind_min_z -= 1;
            }

            //1
            var d1:Float = position.x - min_x;
            var d2:Float = max_x - position.x;


            var max_indicies:Int = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var max_velocity:simd_float3 = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            var max_temperature:Float = temperatureData[max_indicies];
            var min_indicies:Int = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_min_z;
            var min_velocity:simd_float3 = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            var min_temperature:Float = temperatureData[min_indicies];

            p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //2
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_min_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //3
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_min_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
            //4
            max_indicies = ind_max_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            max_velocity = simd_float3(velocityData[max_indicies * 3], velocityData[max_indicies * 3 + 1], velocityData[max_indicies * 3 + 2]);
            max_temperature = temperatureData[max_indicies];
            min_indicies = ind_min_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_max_y * Int(gd.gridSizeZ) + ind_max_z;
            min_velocity = simd_float3(velocityData[min_indicies * 3], velocityData[min_indicies * 3 + 1], velocityData[min_indicies * 3 + 2]);
            min_temperature = temperatureData[min_indicies];

            p4 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
            t4 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

            //5, 6
            d1 = position.z - min_z;
            d2 = max_z - position.z;

            p5 = (d1 * p2 / (d1 + d2)) + (d2 * p1 / (d1 + d2));
            p6 = (d1 * p4 / (d1 + d2)) + (d2 * p3 / (d1 + d2));

            t5 = (d1 * t2 / (d1 + d2)) + (d2 * t1 / (d1 + d2));
            t6 = (d1 * t4 / (d1 + d2)) + (d2 * t3 / (d1 + d2));
            //new
            d1 = position.y - min_y;
            d2 = max_y - position.y;

            newVel = (d1 * p6 / (d1 + d2)) + (d2 * p5 / (d1 + d2));
            newTemp = (d1 * t6 / (d1 + d2)) + (d2 * t5 / (d1 + d2));
        }

        var new_temp:simd_float2 = simd_float2(newTemp, 1.0)

        if((position.y > gd.pc_max_y) || (position.y < gd.pc_min_y)){
            new_temp.y = 0.0;
        }

        // occlusion (ray casting)
        if(volume_occlude) {
            let rotEye:simd_float3 = simd_float3(Float(cos(rotationValue)) * gd.eye.x + Float(sin(rotationValue)) * gd.eye.z,
                                   gd.eye.y,
                                   -Float(sin(rotationValue)) * gd.eye.x + Float(cos(rotationValue)) * gd.eye.z);
            let ray_dir:simd_float3 = simd_normalize(position - rotEye)
            var ray_length:Float = 0.05

            let cube_length:Float = 0.1 //gd.gridLengthX/float(gd.gridSizeX);

            let pointlength:Float = sqrt(pow(position.x - gd.eye.x, 2) + pow(position.y - gd.eye.y, 2) + pow(position.z - gd.eye.z, 2))

            if(pointlength <= ray_length) {
                ray_length = pointlength
            }

            let min_length:Float = Float(sqrt(pow(cube_length,2) + pow(cube_length,2) + pow(cube_length, 2)))

            let ray_num:Int = Int(pointlength/ray_length)

            for i in 1 ..< ray_num {
                let point:simd_float3 = rotEye + Float(i) * ray_length * ray_dir
                let ind_x:Int = Int(Float(gd.gridSizeX)*(point.x - boundary_points[1])/gd.gridLengthX)
                let ind_y:Int = Int(Float(gd.gridSizeY)*(point.y - gd.pc_min_y)/gd.gridLengthY)
                let ind_z:Int = Int(Float(gd.gridSizeZ)*(point.z - boundary_points[3])/gd.gridLengthZ)

                if(ind_x < gd.gridSizeX-1 && ind_x > 0 && ind_y < gd.gridSizeY-1 && ind_y > 0 && ind_z < gd.gridSizeZ-1 && ind_z > 0){
                    
                    let idx:Int = (ind_x * Int(gd.gridSizeY) * Int(gd.gridSizeZ) + ind_y * Int(gd.gridSizeZ) + ind_z)

                    let checklength:Float = Float(sqrt(pow(position.x - gridArray[idx].position.x,2) + pow(position.y - gridArray[idx].position.y,2) + pow(position.z - gridArray[idx].position.z, 2)))
                    
                    if(gridArray[idx].occ && checklength > 1.75 * min_length){
                        new_temp.y = 0.0
                        break
                    }
                }
            }
        }
        
        newVel = simd_float3(Float(cos(-rotationValue)) * newVel.x + Float(sin(-rotationValue)) * newVel.z,
                        newVel.y,
                        Float(-sin(-rotationValue)) * newVel.x + Float(cos(-rotationValue)) * newVel.z)

        return (new_temp, newVel)
    }
    
    func getTemperatureColor(interpolated_temp: Float) -> simd_float4 {
        let newTemperature = Float(1.0 - min(interpolated_temp, 1.0))
        
        if(newTemperature < 0.4){
            return simd_float4(0, 0, 1.0, 0.3)
        }
        else if(newTemperature < 0.6){
            return simd_float4(0, Float((1/0.2)*(newTemperature - 0.4)), 1.0, 0.3)
        }
        else if(newTemperature < 0.75){
            return simd_float4(0.0, 1.0, Float(1.0 - (1/0.15)*(newTemperature - 0.6)), 0.3)
        }
        else if(newTemperature < 0.8){
            return simd_float4(Float((1/0.05)*(newTemperature - 0.75)), 1.0, 0.0, 0.3)
        }
        else if(newTemperature < 0.85){
            return simd_float4(1.0, Float(1.0 - (1/0.05)*(newTemperature - 0.8)), 0.0, 0.3)
        }
        else if(newTemperature <= 1){
            return simd_float4(1.0, 0.0, 0.0, 0.3)
        }
        else {
            return simd_float4(0,0,0,0.0)
        }
    }
    
    func calc_room_dimensions(){
        let P0 = boundary_points[0];
        let P1 = boundary_points[1];
        let P2 = boundary_points[2];
        let P3 = boundary_points[3];
        
        gd.gridSizeX = Int32(gridSizeX)
        gd.gridSizeY = Int32(gridSizeY)
        gd.gridSizeZ = Int32(gridSizeZ)
        gd.gridLengthX = P0 - P1
        gd.gridLengthY = pc_max_y - pc_min_y
        gd.gridLengthZ = P2 - P3
        gd.pc_max_y = pc_max_y
        gd.pc_min_y = pc_min_y
    }
    
    // from 3D to 1D index
    func convert3DIndex(_ x:Int, _ y:Int, _ z:Int) -> (Int, Int) {
        var temperature_idx = 0
        var velocity_idx = 0
        temperature_idx = (x*gridSizeY*gridSizeZ + y*gridSizeZ + z)
        velocity_idx = temperature_idx * 3
        return (temperature_idx, velocity_idx)
    }
    
    // MARK: - One-time functions
    
    func setupRenderSystem(){
        
        // basic camera paramters
        viewPortSize = sceneView.bounds.size
        rotateToARCamera = makeRotateToARCameraMatrix(orientation: orientation)
        
        // model .obj and texture loader
        objBufferAllocator = MTKMeshBufferAllocator(device: device)
        textureCache = makeTextureCache()
        textureLoader = MTKTextureLoader(device: device)
        Material.createDefaultTextures(device: device)
        textureSamplerState = makeTextureSamplerState()
        
        // depth state descriptors
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        relaxedStencilState = device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!
        objDepthStencilState = makeDepthStencilState()
        
        // set obj vertex descriptor (postion, normal, textcoord)
        objVertexDescriptor = MDLVertexDescriptor()
        objVertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        objVertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
        objVertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size * 6, bufferIndex: 0)
        objVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
                        
        // create obj instances
        arrowInstance = createObjInstance(modelName: "arrow1", modelTexture: nil, count: maxArrow)
        arrowInstance.createBuffer(device: device)
        
        gridInstance = createObjInstance(modelName: "box", modelTexture: nil, count: maxGrid)
        gridInstance.createBuffer(device: device)
        
        Particle = Model(model_name: "particle", count: 10_000_000)
        Particle.createBuffer(device: device)
        
        // volume
        volumePlane = Model(model_name: "plane", count: 2_000_000)
        volumePlane.createBuffer(device: device)
        
        // surface
        surfaceModel = Model(model_name: "surface", count: 600_000)
        surfaceModel.createBuffer(device: device)
        
        // line
        lineModel = Model(model_name: "line", count: 300_000)
        lineModel.createBuffer(device: device)
                
        graph = Grapher(sceneView: sceneView, viewPortSize: viewPortSize, orientation: orientation)
        
        // set up global light
        globalLight = lightUniform()
        globalLight.lightAmbient = simd_float3(0.01, 0.01, 0.01)
        globalLight.materialAmbient = simd_float3(0.99, 0.99, 0.99)
        globalLight.lightDiffuse = simd_float3(0.95, 0.95, 0.95)
        globalLight.lightSpecular = simd_float3(0.0, 0.0, 0.0)
        globalLight.materialSpecular = simd_float3(0.0, 0.0, 0.0)
        globalLight.materialShininess = 0.0
    
        // pipeline state
        rgbPipeline = makeRGBPipelineState()
        instancedPipeline = makeInstancedPipelineState()
        objPipeline = makeObjPipelineState()
        primitivePipeline = makePrimitivePipelineState()
        primitiveVolumePipeline = makePrimitiveVolumePipelineState()
        particlePipeline = makeParticlePipelineState()
    }
        
    
    // create instance from .obj file
    func createObjInstance(modelName: String, modelTexture: String?, count: Int) -> ModelInstace? {
        let new_instance: ModelInstace = ModelInstace(model_name: modelName, count: count)
        
        // load obj model and set model descriptor (must follow objVertexDescriptor)
        guard let assetURL = Bundle.main.url(forResource: modelName, withExtension: "obj") else { return nil }
        let new_asset = MDLAsset(url: assetURL, vertexDescriptor: objVertexDescriptor, bufferAllocator: objBufferAllocator)
        new_asset.loadTextures()
    
        for sourceMesh in new_asset.childObjects(of: MDLMesh.self) as! [MDLMesh] {
            sourceMesh.addOrthTanBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate, normalAttributeNamed: MDLVertexAttributeNormal, tangentAttributeNamed: MDLVertexAttributeTangent)
            sourceMesh.vertexDescriptor = objVertexDescriptor
        }
        
        guard let (sourceMeshes, meshes) = try? MTKMesh.newMeshes(asset: new_asset, device: device) else {
            fatalError("Could not convert \(modelName) ModelIO meshes to MetalKit meshes")
        }
        
        for (sourceMesh, mesh) in zip(sourceMeshes, meshes) {
            var materials = [Material]()
            for sourceSubmesh in sourceMesh.submeshes as! [MDLSubmesh] {
                let material = Material(material: sourceSubmesh.material, textureLoader: textureLoader)
                materials.append(material)
            }
            new_instance.mesh = mesh
            new_instance.materials = materials
        }
        
        if let texture_file = modelTexture {
            let textureOptions: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]
            new_instance.texture = try? textureLoader.newTexture(name: texture_file, scaleFactor: 1.0, bundle: nil, options: textureOptions)
        }
        
        new_instance.asset = new_asset
        return new_instance
    }
    
    func makeTextureCache() -> CVMetalTextureCache {
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        return cache
    }
    
    // used only for rgb camera rendering
    func makeTexture(pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        var newTexture: CVMetalTexture!
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &newTexture)
        
        if status == kCVReturnSuccess {
            return newTexture
        } else {
            print("could not create texture for: \(planeIndex)")
            return nil
        }
    }
    
    func makeCubeMap(cubeMapFile: String) {
        do {
            let cubeMapURL = Bundle.main.url(forResource: cubeMapFile, withExtension: "ktx")!
            globalLightingCubeMap = try textureLoader.newTexture(URL: cubeMapURL)
        } catch {
            print("could not make light cube map...")
        }
    }
    
    func makeRGBPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = mtl_library.makeFunction(name: "rgbVertex"),
            let fragmentFunction = mtl_library.makeFunction(name: "rgbFragment") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeInstancedPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = mtl_library.makeFunction(name: "objVertexInstanced"),
            let fragmentFunction = mtl_library.makeFunction(name: "objFragment") else {
                return nil
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        let modelDescriptor = MTKMetalVertexDescriptorFromModelIO(objVertexDescriptor)
        descriptor.vertexDescriptor = modelDescriptor
        return try? device.makeRenderPipelineState(descriptor: descriptor)
        
    }
    
    func makeObjPipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = mtl_library.makeFunction(name: "objVertex"),
            let fragmentFunction = mtl_library.makeFunction(name: "objFragment") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        let modelDescriptor = MTKMetalVertexDescriptorFromModelIO(objVertexDescriptor)
        descriptor.vertexDescriptor = modelDescriptor
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makePrimitivePipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = mtl_library.makeFunction(name: "vertex_shader"),
            let fragmentFunction = mtl_library.makeFunction(name: "fragment_shader") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
//        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
//        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        // [0]: position, [1]: normal, [2]: color -> add additional attributes if needed
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float3>.stride
        
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].offset = MemoryLayout<simd_float3>.stride*2
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride*2 + MemoryLayout<simd_float4>.stride
        descriptor.vertexDescriptor = vertexDescriptor
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makePrimitiveVolumePipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = mtl_library.makeFunction(name: "vertex_shader"),
            let fragmentFunction = mtl_library.makeFunction(name: "fragment_volume_shader") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
//        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
//        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        // [0]: position, [1]: normal, [2]: color -> add additional attributes if needed
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float3>.stride
        
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].offset = MemoryLayout<simd_float3>.stride*2
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride*2 + MemoryLayout<simd_float4>.stride
        descriptor.vertexDescriptor = vertexDescriptor
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeParticlePipelineState() -> MTLRenderPipelineState? {
        guard let vertexFunction = mtl_library.makeFunction(name: "particle_shader"),
            let fragmentFunction = mtl_library.makeFunction(name: "particle_shader_fragment") else {
                return nil
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.depthAttachmentPixelFormat = sceneView.depthPixelFormat
        descriptor.colorAttachments[0].pixelFormat = sceneView.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        // [0]: position, [1]: normal, [2]: color -> add additional attributes if needed
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float3>.stride
        
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].offset = MemoryLayout<simd_float3>.stride*2
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride*2 + MemoryLayout<simd_float4>.stride
        descriptor.vertexDescriptor = vertexDescriptor
        
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func makeDepthStencilState() -> MTLDepthStencilState? {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .greaterEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
    
    func makeTextureSamplerState() -> MTLSamplerState? {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    func drawRectResized(size: CGSize) {
        viewPortSize = size
    }
    
    func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        // flip to ARKit Camera's coordinate
        let flipYZ = matrix_float4x4(
            [1, 0, 0, 0],
            [0, -1, 0, 0],
            [0, 0, -1, 0],
            [0, 0, 0, 1] )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * matrix_float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
    
    func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
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
}


extension String {
    /*
    func fileName() -> String {
        return URL(fileURLWithPath: self).deletePathExtension().lastPathComponent
    }
    
    func fileExtension() -> String {
        return URL(fileURLWithPath: self).pathExtension
    }
     */
}
