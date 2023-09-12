//
//  Compute.swift
//  fluidSimulation
//
//  Created by Donghan Kim on 2022/02/19.
//

import MetalKit

// for gpu compute functions
class Compute {
    private var updateVertex_gpu: MTLFunction!
    private var updateColor_gpu: MTLFunction!
    private var uvPipelineState: MTLComputePipelineState!
    private var ucPipelineState: MTLComputePipelineState!
    
    var bufferSize: Int = 10_000_000
    var volume_spacing: Int = 128
    var plane_num: Int = 5
    private var gridArrayBuffer: MTLBuffer!
    private var boundaryPointsBuffer: MTLBuffer!
    private var verticiesBuffer: MTLBuffer!
    private var temperatureBuffer: MTLBuffer!
    private var velocityBuffer: MTLBuffer!
    private var tempOutputBuffer: MTLBuffer!
    private var velocityOutputBuffer: MTLBuffer!
    
    // variables need for compute functions
    var velocityData:[Float] = []
    var temperatureData:[Float] = []
    var gridArray:[Grid]!
    var boundary_points:[Float]!
    var occlusionGrid:[Grid]!
    var gd = gridUniform()
    var volume_occlude:Bool = false
    var rotationValue:Float = 0.0
    
    init(){ }
    
    func create_pipelinestate(device: MTLDevice, mtl_library: MTLLibrary){
        updateVertex_gpu = mtl_library.makeFunction(name: "updateVertex")
        updateColor_gpu = mtl_library.makeFunction(name: "updateColor")
        do{
            uvPipelineState = try device.makeComputePipelineState(function: updateVertex_gpu)
            ucPipelineState = try device.makeComputePipelineState(function: updateColor_gpu)
        } catch {
            print("could not create pipeline states...")
        }
    }
    
    func createBuffer(device: MTLDevice){
        boundaryPointsBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride*5, options: .storageModeShared)
        gridArrayBuffer = device.makeBuffer(length: MemoryLayout<Grid>.stride*bufferSize, options: .storageModeShared)
        temperatureBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride*bufferSize, options: .storageModeShared)
        velocityBuffer = device.makeBuffer(length: MemoryLayout<Float>.stride*bufferSize, options: .storageModeShared)
        
        velocityOutputBuffer = device.makeBuffer(length: MemoryLayout<simd_float3>.stride*bufferSize, options: .storageModeShared)
        tempOutputBuffer = device.makeBuffer(length: MemoryLayout<simd_float2>.stride*bufferSize, options: .storageModeShared)
    }
        
    func updateBuffers(){
        var boundaryPointer = boundaryPointsBuffer.contents().bindMemory(to: Float.self, capacity: 5)
        var gridPointer = gridArrayBuffer.contents().bindMemory(to: Grid.self, capacity: gridArray.count)
        var temperaturePointer = temperatureBuffer.contents().bindMemory(to: Float.self, capacity: temperatureData.count)
        var velocityPointer = velocityBuffer.contents().bindMemory(to: Float.self, capacity: velocityData.count)
        
        for idx in 0..<boundary_points.count {
            boundaryPointer.pointee = boundary_points[idx]
            boundaryPointer = boundaryPointer.advanced(by: 1)
        }
    
        for idx in 0..<velocityData.count {
            velocityPointer.pointee = velocityData[idx]
            velocityPointer = velocityPointer.advanced(by: 1)
        }
        
        for idx in 0..<temperatureData.count {
            temperaturePointer.pointee = temperatureData[idx]
            temperaturePointer = temperaturePointer.advanced(by: 1)
        }
        
        for idx in 0..<gridArray.count {
            gridPointer.pointee = gridArray[idx]
            gridPointer = gridPointer.advanced(by: 1)
        }
    }
    
    func gpu_interpolate(device: MTLDevice, commandQueue: MTLCommandQueue, verticies:[simd_float3]) -> ([simd_float2], [simd_float3]) {
        var new_temp = [simd_float2].init(repeating: simd_float2(0.0, 0.0), count: verticies.count)
        var new_velocity = [simd_float3].init(repeating: simd_float3(0,0,0), count: verticies.count)
        
        if (temperatureData.count == 0 || velocityData.count == 0 || verticies.count == 0) {
            return (new_temp, new_velocity)
        }
        else {
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
            commandEncoder?.setComputePipelineState(ucPipelineState)
            
            var verticiesBuffer = device.makeBuffer(bytes: verticies, length: MemoryLayout<simd_float3>.stride*verticies.count, options: .storageModeShared)
            
            // set buffers
            commandEncoder?.setBuffer(gridArrayBuffer, offset: 0, index: 0)
            commandEncoder?.setBuffer(boundaryPointsBuffer, offset: 0, index: 1)
            commandEncoder?.setBuffer(verticiesBuffer, offset: 0, index: 2)
            commandEncoder?.setBytes(&gd, length: MemoryLayout<gridUniform>.stride, index: 3)
            commandEncoder?.setBytes(&volume_occlude, length: MemoryLayout<Bool>.stride, index: 4)
            commandEncoder?.setBuffer(temperatureBuffer, offset: 0, index: 5)
            commandEncoder?.setBuffer(velocityBuffer, offset: 0, index: 6)
            commandEncoder?.setBuffer(tempOutputBuffer, offset: 0, index: 7)
            commandEncoder?.setBuffer(velocityOutputBuffer, offset: 0, index: 8)
            commandEncoder?.setBytes(&rotationValue, length: MemoryLayout<Float>.stride, index: 9)
            
            // set threads
            let threadsPerGrid = MTLSize(width: verticies.count, height: 1, depth: 1)
            let maxThreadsPerGroup = ucPipelineState.maxTotalThreadsPerThreadgroup
            let threadsPerTG = MTLSize(width: maxThreadsPerGroup, height: 1, depth: 1)
            commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerTG)
            
            // commit buffer
            commandEncoder?.endEncoding()
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
            
            
            // store buffer outputs
            var temp_output_pointer = tempOutputBuffer?.contents().bindMemory(to: simd_float2.self, capacity: MemoryLayout<simd_float2>.stride*verticies.count)
            var vel_output_pointer = velocityOutputBuffer?.contents().bindMemory(to: simd_float3.self, capacity: MemoryLayout<simd_float3>.stride*verticies.count)
            for i in 0..<verticies.count {
                new_temp[i] = simd_float2(temp_output_pointer!.pointee)
                new_velocity[i] = simd_float3(vel_output_pointer!.pointee)
                
                temp_output_pointer = temp_output_pointer?.advanced(by: 1)
                vel_output_pointer = vel_output_pointer?.advanced(by: 1)
            }
            verticiesBuffer = nil
            return (new_temp, new_velocity)
        }
    }
    
    func gpu_get_plane_vertex(device: MTLDevice, commandQueue: MTLCommandQueue, planePos: planeUniform) -> ([simd_float3], [UInt32]) {
        var new_verticies:[simd_float3] = []; var new_indicies:[UInt32] = []
        var vIdx: Int = 0;
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(uvPipelineState)
    
        var planePosition = planePos
        let buffer_count:Int = volume_spacing*volume_spacing*plane_num
        var vertex_output_buffer = device.makeBuffer(length: MemoryLayout<cubel>.stride*buffer_count, options: .storageModeShared)

        // set buffers
        commandEncoder?.setBytes(&planePosition, length: MemoryLayout<planeUniform>.stride, index: 0)
        commandEncoder?.setBytes(&gd, length: MemoryLayout<gridUniform>.stride, index: 1)
        commandEncoder?.setBuffer(boundaryPointsBuffer, offset: 0, index: 2)
        commandEncoder?.setBuffer(vertex_output_buffer, offset: 0, index: 3)
        
        // set threads
        let threadsPerGrid = MTLSize(width: volume_spacing, height: volume_spacing, depth: plane_num)
        let maxThreadsPerGroup = uvPipelineState.maxTotalThreadsPerThreadgroup
        let threadsPerTG = MTLSize(width: maxThreadsPerGroup, height: 1, depth: 1)
        commandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerTG)
        
        // commit buffer
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
                
        var output_pointer = vertex_output_buffer?.contents().bindMemory(to: cubel.self, capacity: MemoryLayout<cubel>.stride*buffer_count)
        for _ in 0..<buffer_count{
            let cube = output_pointer!.pointee

            new_verticies.append(cube.p0)
            vIdx += 1
            new_verticies.append(cube.p1)
            vIdx += 1
            new_verticies.append(cube.p2)
            vIdx += 1
            new_verticies.append(cube.p5)
            vIdx += 1
            
            new_indicies.append(UInt32(vIdx-4))
            new_indicies.append(UInt32(vIdx-3))
            new_indicies.append(UInt32(vIdx-2))
            new_indicies.append(UInt32(vIdx-2))
            new_indicies.append(UInt32(vIdx-3))
            new_indicies.append(UInt32(vIdx-1))
            
            output_pointer = output_pointer?.advanced(by: 1)
        }
        vertex_output_buffer = nil
        return (new_verticies, new_indicies)
    }
    
    
}
