//
//  IsoSurfaceGenerator.swift
//  sampleApp
//
//  Created by JeongHyeon Ahn on 2022/02/23.
//

import Foundation
import simd

class IsoSurfaceGenerator{
    
    var isoTargetTemp: Float = 0.5
    var size: simd_int3!
    var data:[Float]!
    var step: simd_int3!
    var vertices: [simd_float3]!
    var normals: [simd_float3]!
    var flux: [Float]!
    var inside: [Bool]!
    var gridArray:[Grid]!
    var temp_vert_flux:[simd_float4]!
    
    var res_vertices: [simd_float3]=[]
    var res_faces: [simd_int3]=[]
    var res_normals: [simd_float3] = []
    
    init(){ }
    
    func setGridSize(size:simd_int3, step:simd_int3){
        self.size=size/step
        self.step=step
        
        self.vertices = [simd_float3](repeating: simd_float3(0,0,0),count: Int(self.size.x*self.size.y*self.size.z))
        self.normals = [simd_float3](repeating: simd_float3(0,0,0),count: Int(self.size.x*self.size.y*self.size.z))
        self.flux = [Float](repeating: Float(0),count: Int(self.size.x*self.size.y*self.size.z))
        self.inside = [Bool](repeating: false,count: Int(self.size.x*self.size.y*self.size.z))
        self.temp_vert_flux = [simd_float4](repeating: simd_float4(0,0,0,0),count: 12)
    }
    
    func createIsoSurfaceRenderData() -> [primVert] {
        var new_arr:[primVert] = []
        let color = getTemperatureColor(interpolated_temp: isoTargetTemp)
        for i in 0..<res_faces.count{
            let p1 = primVert(position: res_vertices[Int(res_faces[i].x)], normal: res_normals[Int(res_faces[i].x)], color: color)
            let p2 = primVert(position: res_vertices[Int(res_faces[i].y)], normal: res_normals[Int(res_faces[i].y)], color: color)
            let p3 = primVert(position: res_vertices[Int(res_faces[i].z)], normal: res_normals[Int(res_faces[i].z)], color: color)

            new_arr.append(p1)
            new_arr.append(p3)
            new_arr.append(p2)
        }
        return new_arr
    }
    
    func updateIsoSurface(data: [Float], iso_value: Float){
        self.isoTargetTemp = iso_value
        res_vertices = []
        res_faces = []
        
        var cnt:Int = 0
        //set sampled vertex points
        for ix in 0..<size.x {
            for iy in 0..<size.y{
                for iz in 0..<size.z{
                    let idx=Int(iz + iy*size.z + ix*size.y*size.z)
                    let idx_o=Int(iz*step.z) + Int(iy*step.y*size.z) + Int(ix*step.x*size.y*size.z)
                    vertices[idx] = gridArray[idx].position
                    flux[idx]=data[idx_o]
                    normals[idx]=simd_float3(0,0,0)
                    if abs(data[idx_o]-iso_value)<0.1{
                        inside[idx]=true
                        cnt+=1
                    }
                    else{
                        inside[idx]=false
                    }
                }
            }
        }
        calculate()
        getNormal()
    }
    
    //genetate iso-surface meshes
    func calculate(){
        var cnt:Int = 0
        
        for ix in 0..<size.x-1 {
            for iy in 0..<size.y-1 {
                for iz in 0..<size.z-1 {
                    let idx=Int(iz + iy*size.z + ix*size.y*size.z)
                    let yOff=Int(size.z)
                    let xOff=Int(size.z*size.y)
                    let tv=[idx,idx+1,idx+1+yOff,idx+yOff,
                            idx+xOff,idx+1+xOff,idx+1+yOff+xOff,idx+yOff+xOff]
                    
                    var lookup_idx:UInt8 = 0
                    // find marching cube type
                    if inside[tv[0]]==false{
                        lookup_idx=lookup_idx|1
                    }
                    if inside[tv[1]]==false{
                        lookup_idx=lookup_idx|2
                    }
                    if inside[tv[2]]==false{
                        lookup_idx=lookup_idx|4
                    }
                    if inside[tv[3]]==false{
                        lookup_idx=lookup_idx|8
                    }
                    if inside[tv[4]]==false{
                        lookup_idx=lookup_idx|16
                    }
                    if inside[tv[5]]==false{
                        lookup_idx=lookup_idx|32
                    }
                    if inside[tv[6]]==false{
                        lookup_idx=lookup_idx|64
                    }
                    if inside[tv[7]]==false{
                        lookup_idx=lookup_idx|128
                    }
                    
                    let edge_idx=edgeTable[Int(lookup_idx)]
                    //generate vertices for the type
                    if edge_idx != 0 {
                        if edgeTable[Int(lookup_idx)]&1 != 0 {
                            temp_vert_flux[0]=interpolate(idx1:tv[0],idx2:tv[1])
                        }
                        if edgeTable[Int(lookup_idx)]&2 != 0 {
                            temp_vert_flux[1]=interpolate(idx1:tv[1],idx2:tv[2])
                        }
                        if edgeTable[Int(lookup_idx)]&4 != 0 {
                            temp_vert_flux[2]=interpolate(idx1:tv[2],idx2:tv[3])
                        }
                        if edgeTable[Int(lookup_idx)]&8 != 0 {
                            temp_vert_flux[3]=interpolate(idx1:tv[3],idx2:tv[0])
                        }
                        if edgeTable[Int(lookup_idx)]&16 != 0 {
                            temp_vert_flux[4]=interpolate(idx1:tv[4],idx2:tv[5])
                        }
                        if edgeTable[Int(lookup_idx)]&32 != 0 {
                            temp_vert_flux[5]=interpolate(idx1:tv[5],idx2:tv[6])
                        }
                        if edgeTable[Int(lookup_idx)]&64 != 0 {
                            temp_vert_flux[6]=interpolate(idx1:tv[6],idx2:tv[7])
                        }
                        if edgeTable[Int(lookup_idx)]&128 != 0 {
                            temp_vert_flux[7]=interpolate(idx1:tv[7],idx2:tv[4])
                        }
                        if edgeTable[Int(lookup_idx)]&256 != 0 {
                            temp_vert_flux[8]=interpolate(idx1:tv[0],idx2:tv[4])
                        }
                        if edgeTable[Int(lookup_idx)]&512 != 0 {
                            temp_vert_flux[9]=interpolate(idx1:tv[1],idx2:tv[5])
                        }
                        if edgeTable[Int(lookup_idx)]&1024 != 0 {
                            temp_vert_flux[10]=interpolate(idx1:tv[2],idx2:tv[6])
                        }
                        if edgeTable[Int(lookup_idx)]&2048 != 0 {
                            temp_vert_flux[11]=interpolate(idx1:tv[3],idx2:tv[7])
                        }
                        
                        //generate face for the type
                        var i:Int = 0
                        while triTable[Int(lookup_idx)*16+i] != -1 {
                            
                            let curV1:simd_float3 = temp_vert_flux[triTable[Int(lookup_idx)*16+i]].xyz
                            let curV2:simd_float3 = temp_vert_flux[triTable[Int(lookup_idx)*16+i+1]].xyz
                            let curV3:simd_float3 = temp_vert_flux[triTable[Int(lookup_idx)*16+i+2]].xyz
                            
                            res_vertices.append(curV1)
                            res_vertices.append(curV2)
                            res_vertices.append(curV3)
                            
                            res_faces.append(simd_int3(Int32(cnt*3+0),Int32(cnt*3+1),Int32(cnt*3+2)))
                            
                            cnt=cnt+1
                            i=i+3
                        }

                    }
                }
            }
        }
                
    }
    
    
    func interpolate(idx1:Int,idx2:Int)->simd_float4{
        var res:simd_float4=simd_float4(0,0,0,0)
        res.xyz=(vertices[idx1]+vertices[idx2])*0.5
        res.w=(flux[idx1]+flux[idx2])*0.5
        return res
    }
    
    func getNormal() {
        let nVert=res_vertices.count
        let nFace=res_faces.count
        var normalCnt:[Int]
        
        res_normals = [simd_float3](repeating: simd_float3(0,0,0),count: nVert)
        normalCnt = [Int](repeating: Int(0), count: nVert)

        for i in 0..<nFace{
            let a=res_vertices[Int(res_faces[i].x)]
            let b=res_vertices[Int(res_faces[i].y)]
            let c=res_vertices[Int(res_faces[i].z)]
            
            let tn=simd_normalize(cross(a-b,b-c))
            res_normals[Int(res_faces[i].x)]+=tn
            res_normals[Int(res_faces[i].y)]+=tn
            res_normals[Int(res_faces[i].z)]+=tn
            
            normalCnt[Int(res_faces[i].x)]+=1
            normalCnt[Int(res_faces[i].y)]+=1
            normalCnt[Int(res_faces[i].z)]+=1
        }
        for i in 0..<nVert{
            if normalCnt[i] != 0{
                res_normals[i] = simd_normalize(res_normals[i]/Float(normalCnt[i]))
            }
        }                
    }
    
    func getTemperatureColor(interpolated_temp: Float) -> simd_float4 {
        let newTemp = Float(1.0 - min(interpolated_temp, 1.0))
        
        if(newTemp < 0.6){
            return simd_float4(0, Float((1/0.6)*newTemp), 1.0, 0.9)
        }
        else if(newTemp < 0.9){
            return simd_float4(0.0, 1.0, Float(1.0 - (1/0.3)*(newTemp - 0.6)), 0.9);
        }

        else if(newTemp < 0.925){
            return simd_float4(Float((1/0.025)*(newTemp - 0.9)), 1.0, 0.0, 0.9);
        }

        else if(newTemp <= 1.0){
            return simd_float4(1.0, Float(1.0 - (1/0.075)*(newTemp - 0.925)), 0.0, 0.9);
        }
        else {
            return simd_float4(0,0,0,0);
        }
    }
}
