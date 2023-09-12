//
//  Grapher.swift
//  fluidSimulation
//
//  Created by Donghan Kim on 2022/03/03.
//

import ARKit
import SceneKit
import Charts


class Grapher {
    
    var sceneView: ARSCNView!
    var viewPortSize: CGSize!
    var orientation: UIInterfaceOrientation!
    var graphRootNode: SCNNode!
    var currentRay: Ray!
    
    init(sceneView: ARSCNView, viewPortSize: CGSize, orientation: UIInterfaceOrientation){
        self.sceneView = sceneView
        self.viewPortSize = viewPortSize
        self.orientation = orientation
    }
    
    func initTargetLocation(){
        guard let currentFrame = sceneView.session.currentFrame else {
            print("Could not get current frame AR Session...")
            return
        }
        let camera = currentFrame.camera
        
        // getting N and EYE
        let view_matrix = camera.viewMatrix(for: orientation).transpose.inverse
        let n = simd_float3(view_matrix[0,2], view_matrix[1,2], view_matrix[2,2])
        let eye = simd_float3(view_matrix[0,3], view_matrix[1,3], view_matrix[2,3])
        let At = -1*n
        
        // graph root node
        let rootPos = simd_float3(eye + At)
        currentRay = Ray(origin: rootPos, direction: simd_float3(0,0,-1))
        
        let sphereNode = SCNSphere(radius: 0.05)
        sphereNode.firstMaterial?.diffuse.contents = UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        graphRootNode = SCNNode(geometry: sphereNode)
        graphRootNode.position = SCNVector3(rootPos.x, rootPos.y, rootPos.z)
        graphRootNode.name = "graphRoot"
        sceneView.scene.rootNode.addChildNode(graphRootNode)
    }
    
    func updatePointLocation(dt: Float){
        graphRootNode.position = SCNVector3(currentRay.origin + dt*currentRay.direction)
    }
    
    func screenToWorld(screenPoint: CGPoint) -> SCNVector3? {
        guard let currentFrame = sceneView.session.currentFrame else {
            print("Could not get current frame AR Session...")
            return nil
        }
        let camera = currentFrame.camera
        let viewMatrix = camera.viewMatrix(for: orientation)
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewPortSize, zNear: 0.01, zFar: 0.0)
        let inverseProjection = projectionMatrix.inverse
         
        let clipX = (2*Float(screenPoint.x)) / Float(viewPortSize.width) - 1
        let clipY = 1 - (2*Float(screenPoint.y)) / Float(viewPortSize.height)
        let clipCoords = simd_float4(clipX, clipY, 0.98, 1)
        
        var eyeRayDir = inverseProjection * clipCoords
        eyeRayDir.z = -1
        eyeRayDir.w = 0
        
        var worldRayDir = (viewMatrix.inverse * eyeRayDir).xyz
        worldRayDir = normalize(worldRayDir)
        let worldRayOrigin = (viewMatrix.inverse * simd_float4(0,0,0,1)).xyz
        currentRay = Ray(origin: worldRayOrigin, direction: worldRayDir)
        
        var worldPos = viewMatrix.inverse * inverseProjection * clipCoords
        worldPos.w = (1.0/worldPos.w)
        worldPos.x *= worldPos.w
        worldPos.y *= worldPos.w
        worldPos.z *= worldPos.w
        return SCNVector3(worldPos.x, worldPos.y, worldPos.z)
    }
}



