//
//  AirconditionerModel.swift
//  fluidSimulation
//
//  Created by Donghan Kim on 2022/02/19.
//

import SceneKit
import ARKit

class AirConditioner {

    // models for simulation
    var acNodeArr: [SCNNode] = []
    var ceiling_ac: SCNNode!
    var blade_x1: SCNNode!; var blade_x2: SCNNode!
    var blade_z1: SCNNode!; var blade_z2: SCNNode!

    var wall_ac: SCNNode!
    var wallblade: SCNNode!

    var stand_ac: SCNNode!
    var stdblade1: SCNNode!; var stdblade2: SCNNode!
    var stdblade3: SCNNode!; var stdblade4: SCNNode!
    
    var tower_ac: SCNNode!
    var towerCicle: SCNNode!;
    var towerblade1: SCNNode!; var towerblade2: SCNNode!
    
    var currentACModel:String = "ceiling"
    var currentPosition: simd_float3!
    var currentAngle:Int = 1 //"level1"
    var currentSpeed:Int = 6 //"low"
    var acOrientation:Int = 0
    var current_ceiling_angle:Float = 0.0
    
    var boolGrid:[Bool]!
    var boundary_points:[Float]!
    var pc_max_y: Float = 0
    var pc_min_y: Float = 0
    var gridSizeX:Int = 0
    var gridSizeY:Int = 0
    var gridSizeZ:Int = 0
    
    var rotAxisX:simd_float3 = simd_float3(Float(cos(-0.0)), 0, Float(-sin(-0.0)))
    var rotAxisZ:simd_float3 = simd_float3(Float(sin(-0.0)), 0, Float(cos(-0.0)))
    
    init(){
        loadCeilingModels()
        loadWallModels()
        loadStandModels()
        loadTowerModels()
    }

    func loadCeilingModels(){
        // ceiling ac model
        var tempScene = SCNScene(named: "art.scnassets/ceiling_ac.scn") //수정필요
        ceiling_ac = SCNNode()
        for node in tempScene?.rootNode.childNodes ?? [] {
            node.name = "ACNode"
            ceiling_ac.addChildNode(node as SCNNode)
        }
        ceiling_ac.name = "ACNode"

        // ceiling ac blade model
        tempScene = SCNScene(named: "art.scnassets/ceiling_blade.scn")
        blade_x1 = SCNNode()
        for node in tempScene?.rootNode.childNodes ?? [] {
            node.name = "ACNode"
            blade_x1.addChildNode(node as SCNNode)
        }
        blade_x2 = blade_x1.flattenedClone()
        blade_x2.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: Float.pi)
        blade_z1 = blade_x1.flattenedClone()
        blade_z1.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: -Float.pi/2)
        blade_z2 = blade_x1.flattenedClone()
        blade_z2.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: Float.pi/2)
        
        blade_x1.name = "ACNode"
        blade_x2.name = "ACNode"
        blade_z1.name = "ACNode"
        blade_z2.name = "ACNode"
    }
    
    func loadStandModels(){
        // stand ac
        var tempScene = SCNScene(named: "art.scnassets/stand_ac.scn")
        stand_ac = SCNNode()
        for node in tempScene?.rootNode.childNodes ?? [] {
            node.name = "ACNode"
            stand_ac.addChildNode(node as SCNNode)
        }
        stand_ac.name = "ACNode"

        // stand blade
        tempScene = SCNScene(named: "art.scnassets/stand_blade.scn")
        stdblade1 = SCNNode()
        for node in tempScene?.rootNode.childNodes ?? [] {
            node.name = "ACNode"
            stdblade1.addChildNode(node as SCNNode)
        }
        stdblade2 = stdblade1.flattenedClone()
        stdblade3 = stdblade1.flattenedClone()
        stdblade4 = stdblade1.flattenedClone()
        
        stdblade1.name = "ACNode"
        stdblade2.name = "ACNode"
        stdblade3.name = "ACNode"
        stdblade4.name = "ACNode"
    }
    
    func loadWallModels(){
        // wall ac
        var tempScene = SCNScene(named: "art.scnassets/wall_ac.scn")
        wall_ac = SCNNode()
        for node in tempScene?.rootNode.childNodes ?? [] {
            node.name = "ACNode"
            wall_ac.addChildNode(node as SCNNode)
        }
        wall_ac.name = "ACNode"

        // wall blade -> check up on this...
        tempScene = SCNScene(named: "art.scnassets/wall_blade.scn")
        wallblade = SCNNode()
        for node in tempScene?.rootNode.childNodes ?? [] {
            node.name = "ACNode"
            wallblade.addChildNode(node as SCNNode)
        }
        wallblade.name = "ACNode"
    }
    
    func loadTowerModels(){
        // tower ac
        var tempScene = SCNScene(named: "art.scnassets/tower_ac.scn")
        tower_ac = SCNNode()
        for node in tempScene?.rootNode.childNodes ?? [] {
            node.name = "ACNode"
            tower_ac.addChildNode(node as SCNNode)
        }
        tower_ac.name = "ACNode"
    }
    
//    func loadModels(){
//        // ceiling ac model
//        var tempScene = SCNScene(named: "art.scnassets/ceiling_ac.scn") //수정필요
//        ceiling_ac = SCNNode()
//        for node in tempScene?.rootNode.childNodes ?? [] {
//            node.name = "ACNode"
//            ceiling_ac.addChildNode(node as SCNNode)
//        }
//        ceiling_ac.name = "ACNode"
//
//        // ceiling ac blade model
//        tempScene = SCNScene(named: "art.scnassets/ceiling_blade.scn")
//        blade_x1 = SCNNode()
//        for node in tempScene?.rootNode.childNodes ?? [] {
//            node.name = "ACNode"
//            blade_x1.addChildNode(node as SCNNode)
//        }
//        blade_x2 = blade_x1.flattenedClone()
//        blade_x2.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: Float.pi)
//        blade_z1 = blade_x1.flattenedClone()
//        blade_z1.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: -Float.pi/2)
//        blade_z2 = blade_x1.flattenedClone()
//        blade_z2.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: Float.pi/2)
//
//        blade_x1.name = "ACNode"
//        blade_x2.name = "ACNode"
//        blade_z1.name = "ACNode"
//        blade_z2.name = "ACNode"
//
//        // stand ac
//        tempScene = SCNScene(named: "art.scnassets/stand_ac.scn")
//        stand_ac = SCNNode()
//        for node in tempScene?.rootNode.childNodes ?? [] {
//            node.name = "ACNode"
//            stand_ac.addChildNode(node as SCNNode)
//        }
//        stand_ac.name = "ACNode"
//
//        // stand blade
//        tempScene = SCNScene(named: "art.scnassets/stand_blade.scn")
//        stdblade1 = SCNNode()
//        for node in tempScene?.rootNode.childNodes ?? [] {
//            node.name = "ACNode"
//            stdblade1.addChildNode(node as SCNNode)
//        }
//        stdblade2 = stdblade1.flattenedClone()
//        stdblade3 = stdblade1.flattenedClone()
//        stdblade4 = stdblade1.flattenedClone()
//
//        stdblade1.name = "ACNode"
//        stdblade2.name = "ACNode"
//        stdblade3.name = "ACNode"
//        stdblade4.name = "ACNode"
//
//        // wall ac
//        tempScene = SCNScene(named: "art.scnassets/wall_ac.scn")
//        wall_ac = SCNNode()
//        for node in tempScene?.rootNode.childNodes ?? [] {
//            node.name = "ACNode"
//            wall_ac.addChildNode(node as SCNNode)
//        }
//        wall_ac.name = "ACNode"
//
//        // wall blade -> check up on this...
//        tempScene = SCNScene(named: "art.scnassets/wall_blade.scn")
//        wallblade = SCNNode()
//        for node in tempScene?.rootNode.childNodes ?? [] {
//            node.name = "ACNode"
//            wallblade.addChildNode(node as SCNNode)
//        }
//        wallblade.name = "ACNode"
//
//        // tower ac
//        tempScene = SCNScene(named: "art.scnassets/tower_ac.scn")
//        tower_ac = SCNNode()
//        for node in tempScene?.rootNode.childNodes ?? [] {
//            node.name = "ACNode"
//            tower_ac.addChildNode(node as SCNNode)
//        }
//        tower_ac.name = "ACNode"
//    }
    
    
    func get_model_id(model_name: String) -> Int {
        switch currentACModel {
            case "wall":
                return 1
            case "ceiling":
                return 2
            case "stand":
                return 3
            case "tower":
                return 4
            default:
                return 10;
        }
    }

//    func get_speed_id(ac_speed: String) -> Int {
//        switch ac_speed {
//            case "low":
//                return 1
//            case "medium":
//                return 2
//            case "high":
//                return 3
//            default:
//                return 10;
//        }
//    }

    func get_angle_id(ac_angle: String) -> Int {
        switch currentAngle {
            case 1:
                return 1
            case 2:
                return 2
            case 3:
                return 3
            case 4:
                return 4
            case 5:
                return 5
            case 6:
                return 6
            case 7:
                return 7
            default:
                return 0;
        }
    }

    func rotate_blade(angle:Float) -> (simd_quatf, simd_quatf, simd_quatf) {
        let x2_axis = simd_quatf(angle: Float.pi, axis: simd_float3(0.0, 1.0, 0.0))
        let z1_axis = simd_quatf(angle: -Float.pi/2, axis: simd_float3(0.0, 1.0, 0.0))
        let z2_axis = simd_quatf(angle: Float.pi/2, axis: simd_float3(0.0, 1.0, 0.0))

        let x2_rot = simd_quatf(angle: angle, axis: simd_float3(1.0, 0.0, 0.0))
        let z1_rot = simd_quatf(angle: angle, axis: simd_float3(1.0, 0.0, 0.0))
        let z2_rot = simd_quatf(angle: angle, axis: simd_float3(1.0, 0.0, 0.0))

        let x2 = simd_mul(x2_axis, x2_rot)
        let z1 = simd_mul(z1_axis, z1_rot)
        let z2 = simd_mul(z2_axis, z2_rot)

        return (x2, z1, z2)
    }

    var blade_timer:Timer?
    func start_blade_swing(){
        // reset blade orientation
        blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -25-current_ceiling_angle), axis: simd_float3(1,0,0)))
        blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -25-current_ceiling_angle), axis: simd_float3(1,0,0)))
        blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -25-current_ceiling_angle), axis: simd_float3(1,0,0)))
        blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -25-current_ceiling_angle), axis: simd_float3(1,0,0)))
        
        current_ceiling_angle = -25
        blade_timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(swing_blades), userInfo: nil, repeats: true)
    }

    var delta:Float = 0.155; var mult:Float = 1.0

    @objc func swing_blades() {
        if currentACModel == "ceiling" {
            if current_ceiling_angle <= -70 {
                mult = 1.0
            }
            else if current_ceiling_angle >= -25 {
                mult = -1.0
            }

            current_ceiling_angle += mult * delta
            blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(1,0,0)))
            blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(1,0,0)))
            blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(1,0,0)))
            blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(1,0,0)))
        }
        else if currentACModel == "stand" {
            if current_ceiling_angle <= -40 {
                mult = 1.0
            }
            else if current_ceiling_angle >= 40 {
                mult = -1.0
            }
            current_ceiling_angle += mult * delta
            stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(0,0,1)))
            stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(0,0,1)))
            stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(0,0,1)))
            stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(0,0,1)))

        }
        else if currentACModel == "wall" {
            if current_ceiling_angle <= 25 {
                mult = 1.0
            }
            else if current_ceiling_angle >= 85 {
                mult = -1.0
            }
            current_ceiling_angle += mult * delta
            wallblade.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: mult * delta), axis: simd_float3(1,0,0)))

        }
    }

    func get_rotation_quat(newDirection: SCNVector3) -> SCNVector4 {
        let theta = acos(-1*newDirection.x/(sqrt(pow(newDirection.x, 2) + pow(newDirection.y, 2) + pow(newDirection.z, 2))))
        let qaxis = simd.normalize(simd_float3(newDirection.y, -1*newDirection.x, 0.0))
        let quat = simd_quatf(angle: theta, axis: qaxis)
        return SCNVector4(quat.axis.x, quat.axis.y, quat.axis.z, quat.angle)
    }

    var rotate_delta: Float = 1.0
    func left_rotate_pressed() {
        if acNodeArr.count == 0 { return }
        
        if currentACModel == "ceiling" {
            ceiling_ac.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -rotate_delta), axis: simd_float3(0,1,0)))

            // reset blade orientation
            blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))

            blade_x1.position = ceiling_ac.position
            blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -rotate_delta), axis: simd_float3(0,1,0)))
            blade_x1.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            blade_x2.position = ceiling_ac.position
            blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -rotate_delta), axis: simd_float3(0,1,0)))
            blade_x2.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            blade_z1.position = ceiling_ac.position
            blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -rotate_delta), axis: simd_float3(0,1,0)))
            blade_z1.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            blade_z2.position = ceiling_ac.position
            blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -rotate_delta), axis: simd_float3(0,1,0)))
            blade_z2.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            // revert back to the current level
            blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))

        }

        else if currentACModel == "stand" {
            stand_ac.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: 90), axis: simd_float3(0,1,0)))

            // reset blade orientation
            stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))

            stdblade1.position = stand_ac.position
            stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: 90), axis: simd_float3(0,1,0)))
            stdblade1.simdLocalTranslate(by: simd_float3(-0.0298, 1.6807, 0.0))

            stdblade2.position = stand_ac.position
            stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: 90), axis: simd_float3(0,1,0)))
            stdblade2.simdLocalTranslate(by: simd_float3(-0.0298, 1.6107, 0.0))

            stdblade3.position = stand_ac.position
            stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: 90), axis: simd_float3(0,1,0)))
            stdblade3.simdLocalTranslate(by: simd_float3(-0.0298, 1.5407, 0.0))

            stdblade4.position = stand_ac.position
            stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: 90), axis: simd_float3(0,1,0)))
            stdblade4.simdLocalTranslate(by: simd_float3(-0.0298, 1.4707, 0.0))

            // revert back to the current level
            stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
        }
        
        else if currentACModel == "tower" {
            tower_ac.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: 45), axis: simd_float3(0,1,0)))
            if (acOrientation == 1 || acOrientation == 3 || acOrientation == 5 || acOrientation == 7)
            {
                tower_ac.position = SCNVector3(currentPosition.x, currentPosition.y, currentPosition.z)
            }
            else {
                if (acOrientation == 0)
                {
                    tower_ac.position = SCNVector3(currentPosition.x, currentPosition.y, currentPosition.z-0.05)
                }
                else if (acOrientation == 2)
                {
                    tower_ac.position = SCNVector3(currentPosition.x-0.05, currentPosition.y, currentPosition.z)
                }
                else if (acOrientation == 4)
                {
                    tower_ac.position = SCNVector3(currentPosition.x, currentPosition.y, currentPosition.z+0.05)
                }
                else if (acOrientation == 6)
                {
                    tower_ac.position = SCNVector3(currentPosition.x+0.05, currentPosition.y, currentPosition.z)
                }
            }
        }
    }

    func right_rotate_pressed(){
        if acNodeArr.count == 0 { return }
        
        if currentACModel == "ceiling" {
            ceiling_ac.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: rotate_delta), axis: simd_float3(0,1,0)))

            // reset blade orientation
            blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(1,0,0)))

            blade_x1.position = ceiling_ac.position
            blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: rotate_delta), axis: simd_float3(0,1,0)))
            blade_x1.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            blade_x2.position = ceiling_ac.position
            blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: rotate_delta), axis: simd_float3(0,1,0)))
            blade_x2.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            blade_z1.position = ceiling_ac.position
            blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: rotate_delta), axis: simd_float3(0,1,0)))
            blade_z1.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            blade_z2.position = ceiling_ac.position
            blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: rotate_delta), axis: simd_float3(0,1,0)))
            blade_z2.simdLocalTranslate(by: simd_float3(0.0, -0.0095, -0.36))

            // revert back to the current level
            blade_x1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_x2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))
            blade_z2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(1,0,0)))
        }

        else if currentACModel == "stand" {
            stand_ac.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -90), axis: simd_float3(0,1,0)))

            // reset blade orientation
            stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -current_ceiling_angle), axis: simd_float3(0,0,1)))

            stdblade1.position = stand_ac.position
            stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -90), axis: simd_float3(0,1,0)))
            stdblade1.simdLocalTranslate(by: simd_float3(-0.0298, 1.6807, 0.0))

            stdblade2.position = stand_ac.position
            stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -90), axis: simd_float3(0,1,0)))
            stdblade2.simdLocalTranslate(by: simd_float3(-0.0298, 1.6107, 0.0))

            stdblade3.position = stand_ac.position
            stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -90), axis: simd_float3(0,1,0)))
            stdblade3.simdLocalTranslate(by: simd_float3(-0.0298, 1.5407, 0.0))

            stdblade4.position = stand_ac.position
            stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -90), axis: simd_float3(0,1,0)))
            stdblade4.simdLocalTranslate(by: simd_float3(-0.0298, 1.4707, 0.0))

            // revert back to the current level
            stdblade1.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade2.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade3.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
            stdblade4.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: current_ceiling_angle), axis: simd_float3(0,0,1)))
        }
        
        else if currentACModel == "tower" {
            tower_ac.simdLocalRotate(by: simd_quatf(angle: radians(fromDegrees: -45), axis: simd_float3(0,1,0)))
            if (acOrientation == 1 || acOrientation == 3 || acOrientation == 5 || acOrientation == 7)
            {
                tower_ac.position = SCNVector3(currentPosition.x, currentPosition.y, currentPosition.z)
            }
            else {
                if (acOrientation == 0)
                {
                    tower_ac.position = SCNVector3(currentPosition.x-0.05*rotAxisZ.x, currentPosition.y, currentPosition.z-0.05*rotAxisZ.z)
                }
                else if (acOrientation == 2)
                {
                    tower_ac.position = SCNVector3(currentPosition.x-0.05*rotAxisX.x, currentPosition.y, currentPosition.z-0.05*rotAxisX.z)
                }
                else if (acOrientation == 4)
                {
                    tower_ac.position = SCNVector3(currentPosition.x+0.05*rotAxisZ.x, currentPosition.y, currentPosition.z+0.05*rotAxisZ.z)
                }
                else if (acOrientation == 6)
                {
                    tower_ac.position = SCNVector3(currentPosition.x+0.05*rotAxisX.x, currentPosition.y, currentPosition.z+0.05*rotAxisX.z)
                }
            }
        }
    }

    var up_dir_timer:Timer?
    func up_pressed(){
        if acNodeArr.count != 0 {
            up_dir_timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(move_ac_up_dir), userInfo: nil, repeats: true)
        }
    }

    @objc func move_ac_up_dir(){
        if currentACModel == "ceiling" {
            ceiling_ac.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_x1.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_x2.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_z1.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_z2.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            currentPosition = simd_float3(ceiling_ac.position.x, ceiling_ac.position.y, ceiling_ac.position.z)
        }
        else if currentACModel == "stand" {
            stand_ac.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade1.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade2.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade3.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade4.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            currentPosition = simd_float3(stand_ac.position.x, stand_ac.position.y, stand_ac.position.z)
        }
        else if currentACModel == "tower" {
            currentPosition += simd_float3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            tower_ac.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
        }
        else if currentACModel == "wall" {
            wall_ac.position.y += 0.1
            wallblade.position.y += 0.1
            currentPosition = simd_float3(wall_ac.position.x, wall_ac.position.y, wall_ac.position.z)
        }
    }

    var left_dir_timer:Timer?
    func left_pressed(){
        if acNodeArr.count != 0 {
            left_dir_timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(move_ac_left_dir), userInfo: nil, repeats: true)
        }
    }

    @objc func move_ac_left_dir(){
        if currentACModel == "ceiling"{
            ceiling_ac.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_x1.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_x2.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_z1.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_z2.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            currentPosition = simd_float3(ceiling_ac.position.x, ceiling_ac.position.y, ceiling_ac.position.z)
        }
        else if currentACModel == "stand" {
            stand_ac.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade1.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade2.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade3.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade4.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            currentPosition = simd_float3(stand_ac.position.x, stand_ac.position.y, stand_ac.position.z)
        }
        else if currentACModel == "tower" {
            currentPosition -= simd_float3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            tower_ac.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
        }
        else if currentACModel == "wall" {
            switch acOrientation {
                case 4: //"plus_x"
                    wall_ac.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                    wallblade.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                case 0: //"minus_x"
                    wall_ac.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                    wallblade.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                case 2: //"plus_z"
                    wall_ac.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                    wallblade.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                case 6: //"minus_z"
                    wall_ac.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                    wallblade.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                default:
                    return
            }
            currentPosition = simd_float3(wall_ac.position.x, wall_ac.position.y, wall_ac.position.z)
        }
    }

    var down_dir_timer:Timer?
    func down_pressed(){
        if acNodeArr.count != 0 {
            down_dir_timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(move_ac_down_dir), userInfo: nil, repeats: true)
        }
    }

    @objc func move_ac_down_dir(){
        if currentACModel == "ceiling" {
            ceiling_ac.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_x1.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_x2.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_z1.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            blade_z2.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            currentPosition = simd_float3(ceiling_ac.position.x, ceiling_ac.position.y, ceiling_ac.position.z)
        }
        else if currentACModel == "stand" {
            stand_ac.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade1.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade2.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade3.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            stdblade4.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            currentPosition = simd_float3(stand_ac.position.x, stand_ac.position.y, stand_ac.position.z)
        }
        else if currentACModel == "tower" {
            currentPosition -= simd_float3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            tower_ac.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
        }
        else if currentACModel == "wall" {
            wall_ac.position.y -= 0.1
            wallblade.position.y -= 0.1
            currentPosition = simd_float3(wall_ac.position.x, wall_ac.position.y, wall_ac.position.z)
        }
    }

    var right_dir_timer:Timer?
    func right_pressed(){
        if acNodeArr.count != 0 {
            right_dir_timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(move_ac_right_dir), userInfo: nil, repeats: true)
        }
    }

    @objc func move_ac_right_dir(){
        if currentACModel == "ceiling" {
            ceiling_ac.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_x1.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_x2.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_z1.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            blade_z2.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
            currentPosition = simd_float3(ceiling_ac.position.x, ceiling_ac.position.y, ceiling_ac.position.z)
        }
        else if currentACModel == "stand" {
            stand_ac.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade1.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade2.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade3.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            stdblade4.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            currentPosition = simd_float3(stand_ac.position.x, stand_ac.position.y, stand_ac.position.z)
        }
        else if currentACModel == "tower" {
            currentPosition += simd_float3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
            tower_ac.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
        }
        else if currentACModel == "wall" {
            switch acOrientation {
                case 4: //"plus_x"
                    wall_ac.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                    wallblade.position += SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                case 0: //"minus_x"
                    wall_ac.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                    wallblade.position -= SCNVector3(0.1*rotAxisZ.x, 0, 0.1*rotAxisZ.z)
                case 2: //"plus_z"
                    wall_ac.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                    wallblade.position -= SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                case 6: //"minus_z"
                    wall_ac.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                    wallblade.position += SCNVector3(0.1*rotAxisX.x, 0, 0.1*rotAxisX.z)
                default:
                    return
            }
            currentPosition = simd_float3(wall_ac.position.x, wall_ac.position.y, wall_ac.position.z)
        }
    }
    
    // from 3D to 1D index
    func convert3DIndex(_ x:Int, _ y:Int, _ z:Int) -> (Int, Int) {
        var temperature_idx = 0
        var velocity_idx = 0
        temperature_idx = (x*gridSizeY*gridSizeZ + y*gridSizeZ + z)
        velocity_idx = temperature_idx * 3
        return (temperature_idx, velocity_idx)
    }
}
