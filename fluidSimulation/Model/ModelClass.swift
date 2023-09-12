//
//  ModelInstance.swift
//  fluidSimulation
//
//  Created by Donghan Kim on 2022/02/19.
//

import MetalKit
import SceneKit
import ARKit
import simd

// base node
/*
 struct objNode {
     var name: String
     var identifier: Int
     var position: simd_float3 = simd_float3(0,0,0)
     var rotation: simd_float4x4 = matrix_identity_float4x4
     var scale: simd_float4x4 = matrix_identity_float4x4
     var color: simd_float4 = simd_float4(255,240,0,0.3)
     var hitTest: Bool = false
 }
*/

// for volume rendering (change coming soon)
struct planel {
    var node: SCNNode!
    var verticies:[simd_float3] = []
    var temperature:[simd_float2] = []
}

// for streamribbon
struct ribbon_elem {
    var origin:simd_float3 = simd_float3(0,0,0)
    var pointArray:[simd_float3] = []
    var line:String = ""
    var vertices:[primVert] = []
    var indices:[UInt32] = []
}


// corner detection
struct plane_geom {
    var planeNode: SCNNode!
    var planeAnchor: ARPlaneAnchor!
    var plane_normal: SCNVector3 = SCNVector3(0,0,0)
    var d: Float = 0.0
    var max_y: Float = 0.0
    var bottom_left: SCNVector3 = SCNVector3(0,0,0)
    var top_left: SCNVector3 = SCNVector3(0,0,0)
    var bottom_right: SCNVector3 = SCNVector3(0,0,0)
    var top_right: SCNVector3 = SCNVector3(0,0,0)
    
    var leftEdge:Bool = false //additional
    var rightEdge:Bool = false //additional
}

// for ray-casting
struct Ray {
    var origin: simd_float3
    var direction: simd_float3
    
    static func *(transform: simd_float4x4, ray: Ray) -> Ray {
        let originT = (transform * simd_float4(ray.origin, 1)).xyz
        let directionT = (transform * simd_float4(ray.direction, 0)).xyz
        return Ray(origin: originT, direction: directionT)
    }
}

struct BoundingBox {
    var vmin: simd_float3!
    var vmax: simd_float3!
    
    init(vmin: simd_float3, vmax: simd_float3){
        self.vmin = vmin
        self.vmax = vmax
    }
        
    func intersectionPoint(ray: Ray) -> Bool {
        var tmin = (vmin.x - ray.origin.x) / ray.direction.x
        var tmax = (vmax.x - ray.origin.x) / ray.direction.x
        if (tmin > tmax) { swap(&tmin, &tmax) }
        
        var tymin = (vmin.y - ray.origin.y) / ray.direction.y
        var tymax = (vmax.y - ray.origin.y) / ray.direction.y
        if (tymin > tymax) { swap(&tymin, &tymax) }
        
        if tmin > tymax || tymin > tmax {
            return false
        }
        
        if tymin > tmin {
            tmin = tymin
        }
        
        if tymax < tmax {
            tmax = tymax
        }
        
        var tzmin = (vmin.z - ray.origin.z) / ray.direction.z
        var tzmax = (vmax.z - ray.origin.z) / ray.direction.z
        if(tzmin > tzmax ) { swap(&tzmin, &tzmax) }
        
        if tmin > tzmax || tzmin > tmax {
            return false
        }
        
        if tzmin > tmin {
            tmin = tzmin
        }
        
        if tzmax < tmax {
            tmax = tzmax
        }
        return true
    }
}

class objNode {
    var name: String!
    let identifier = UUID()
    var position: simd_float3!
    var rotation: simd_float4x4 = matrix_identity_float4x4
    var scale: simd_float4x4 = matrix_identity_float4x4
    var color: simd_float4 = simd_float4(255,240,0,0.3)
    var modelToWorld: simd_float4x4
    var bb: BoundingBox!
    var hit: Bool = false
    
    init(name: String, position: simd_float3, rotation: simd_float4x4, scale: simd_float4x4, color: simd_float4) {
        self.name = name
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.color = color
        
        self.modelToWorld = float4x4(translation: position) * rotation * scale
        let sizeX = scale.columns.0.x*0.375; let sizeY = scale.columns.1.y*0.375; let sizeZ = scale.columns.2.z*0.375;
        self.bb = BoundingBox(vmin: simd_float3(position.x - sizeX/2, position.y - sizeY/2, position.z - sizeZ/2), vmax: simd_float3(position.x + sizeX/2, position.y + sizeY/2, position.z + sizeZ/2))
    }
    
    func hitTest(_ ray: Ray) -> simd_float3? {
        if bb.intersectionPoint(ray: ray) {
            return position
        }
        else {
            return nil
        }
        
    }
    
}

class Model {
    var maxVerticies: Int!
    var model_name: String
    var verticies: [primVert] = []
    var indicies: [UInt32] = []
    var verticiesBuffer: MTLBuffer!
    var modelMat: simd_float4x4 = matrix_identity_float4x4
    var verticiesCount: Int = 0
    
    // for indexed rendering
    var indexBuffer: MTLBuffer!
    var indexType: MTLIndexType = .uint32
    var indexCount:Int = 0
    
    init(model_name: String, count: Int){
        self.model_name = model_name
        self.maxVerticies = count
    }
    
    func createBuffer(device: MTLDevice){
        verticiesBuffer = device.makeBuffer(length: MemoryLayout<primVert>.stride*maxVerticies, options: [])
        indexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.stride*maxVerticies, options: [])
    }
    
    func updateBufferContents(updatedVerticies: [primVert]) {
        var pointer = verticiesBuffer.contents().bindMemory(to: primVert.self, capacity: updatedVerticies.count)
        
        for vertexData in updatedVerticies {
            pointer.pointee = vertexData
            pointer = pointer.advanced(by: 1)
        }
        verticiesCount = updatedVerticies.count
    }
    
    func updateIndexBufferContents(updatedIndicies: [UInt32]){
        var pointer = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: updatedIndicies.count)
        
        for index in updatedIndicies {
            pointer.pointee = index
            pointer = pointer.advanced(by: 1)
        }
        indexCount = updatedIndicies.count
    }
    
}

class ModelInstace {
    
    var model_name: String
    var modelConstantsBuffer: MTLBuffer!
    var currentCount: Int = 0
    var maxInstance: Int!
    
    // obj data
    var mesh: MTKMesh!
    var asset: MDLAsset!
    var texture: MTLTexture!
    var materials: [Material]!
    
    init(model_name: String, count: Int){
        self.model_name = model_name
        self.maxInstance = count
    }
    
    func createBuffer(device: MTLDevice){
        modelConstantsBuffer = device.makeBuffer(length: MemoryLayout<modelUniforms>.stride*maxInstance, options: [])
    }
    
    func updateModelConstant(objNodes: [objNode]){
        var pointer = modelConstantsBuffer.contents().bindMemory(to: modelUniforms.self, capacity: objNodes.count)
        currentCount = objNodes.count
        for obj in objNodes {
            let modelMat = float4x4(translation: obj.position) * obj.rotation * obj.scale
            let normalMat = simd_matrix(modelMat.columns.0.xyz, modelMat.columns.1.xyz, modelMat.columns.2.xyz)
            pointer.pointee.modelMat = modelMat
            pointer.pointee.normalMat = simd_transpose(simd_inverse(normalMat))
            
            if obj.hit {
                pointer.pointee.color = simd_float4(1,0,0,0.8)
            }
            else {
                pointer.pointee.color = obj.color
            }
            pointer = pointer.advanced(by: 1)
        }
    }
    
    // for ModelIO based Materials
    func setMaterials(materials: [Material]) {
        assert(mesh.submeshes.count == materials.count)
        self.materials = materials
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, useMaterial: Bool) {
        guard let mesh = self.mesh,
              let materials = self.materials else { return }
        
        for (bufferIndex, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: bufferIndex)
        }
        
        for (submeshIndex, submesh) in mesh.submeshes.enumerated() {
            if useMaterial {
                let curr_mat = materials[submeshIndex]
                Material.bindTextures(curr_mat, renderEncoder)
            }
            else if model_name == "arrow1" || model_name == "box" || model_name == "particle" {
                renderEncoder.setFragmentTexture(texture, index: 0)
            }
            let indexBuffer = submesh.indexBuffer
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: indexBuffer.buffer,
                                                indexBufferOffset: indexBuffer.offset,
                                                instanceCount: currentCount)
        }
    }
}

enum TextureIndex: Int {
    case baseColor
    case metallic
    case roughness
    case normal
    case emissive
    case irradiance = 9
}

// for ModelIO Material
class Material {
    
    static var defaultTexture: MTLTexture!
    static var defaultNormalMap: MTLTexture!
    var baseColor: MTLTexture?
    var metallic: MTLTexture?
    var roughness: MTLTexture?
    var normal: MTLTexture?
    var emissive: MTLTexture?
    
    init(material sourceMaterial: MDLMaterial?, textureLoader: MTKTextureLoader) {
        baseColor = texture(for: .baseColor, in: sourceMaterial, textureLoader: textureLoader)
        metallic = texture(for: .metallic, in: sourceMaterial, textureLoader: textureLoader)
        roughness = texture(for: .roughness, in: sourceMaterial, textureLoader: textureLoader)
        normal = texture(for: .tangentSpaceNormal, in: sourceMaterial, textureLoader: textureLoader)
        emissive = texture(for: .emission, in: sourceMaterial, textureLoader: textureLoader)
    }
    
    func texture(for semantic: MDLMaterialSemantic, in material: MDLMaterial?, textureLoader: MTKTextureLoader) -> MTLTexture? {
        guard let materialProperty = material?.property(with: semantic) else { return nil }
        guard let sourceTexture = materialProperty.textureSamplerValue?.texture else { return nil }
        
        let wantMips = materialProperty.semantic != .tangentSpaceNormal
        let options: [MTKTextureLoader.Option : Any] = [ .generateMipmaps : wantMips ]
        
        do {
            let new_texture = try textureLoader.newTexture(texture: sourceTexture, options: options)
            print("success for: \(semantic)")
            return new_texture
        } catch {
            print("failure for: \(semantic)")
            return nil
        }
    }
    
    static func createDefaultTextures(device: MTLDevice){
        let bounds = MTLRegionMake2D(0, 0, 1, 1)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: bounds.size.width, height: bounds.size.height,mipmapped: false)
        descriptor.usage = .shaderRead
        
        Material.defaultTexture = device.makeTexture(descriptor: descriptor)!
        let defaultColor: [UInt8] = [ 0, 0, 0, 255 ]
        Material.defaultTexture.replace(region: bounds, mipmapLevel: 0, withBytes: defaultColor, bytesPerRow: 4)
        Material.defaultNormalMap = device.makeTexture(descriptor: descriptor)!
        let defaultNormal: [UInt8] = [ 127, 127, 255, 255 ]
        Material.defaultNormalMap.replace(region: bounds, mipmapLevel: 0, withBytes: defaultNormal, bytesPerRow: 4)
    }
    
    static func bindTextures(_ material: Material, _ renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setFragmentTexture(material.baseColor ?? defaultTexture, index: TextureIndex.baseColor.rawValue)
        renderEncoder.setFragmentTexture(material.metallic ?? defaultTexture, index: TextureIndex.metallic.rawValue)
        renderEncoder.setFragmentTexture(material.roughness ?? defaultTexture, index: TextureIndex.roughness.rawValue)
        renderEncoder.setFragmentTexture(material.normal ?? defaultNormalMap, index: TextureIndex.normal.rawValue)
        renderEncoder.setFragmentTexture(material.emissive ?? defaultTexture, index: TextureIndex.emissive.rawValue)
    }
}


