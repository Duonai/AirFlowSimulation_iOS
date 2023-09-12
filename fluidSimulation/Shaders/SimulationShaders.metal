//
//  SimulationShaders.metal
//  AirSim_IEEEVR
//
//  Created by Donghan Kim on 2021/08/08.
//


#include <metal_stdlib>
#import <metal_relational>
#include <simd/simd.h>

using namespace metal;

constant int volume_spacing = 128;

struct Grid {
    int pointCount;
    bool occ;
    bool fixed;
    float3 position;
};

struct cubel {
    float3 p0;
    float3 p1;
    float3 p2;
    float3 p3;
    float3 p4;
    float3 p5;
};

struct planeUniform {
    float3 AT;
    float3 U;
    float3 V;
    float3 p0;
    float3 p1;
    float3 p2;
    float3 p3;
};

struct gridUniform {
    int gridSizeX;
    int gridSizeY;
    int gridSizeZ;
    float3 eye;
    float pc_max_y;
    float pc_min_y;
    float gridLengthX;
    float gridLengthY;
    float gridLengthZ;
};


// MARK: - Kernel Functions

kernel void updateColor(constant Grid *gridArray [[buffer(0)]],
                        constant float *boundary_points [[buffer(1)]],
                        constant simd_float3 *verticies [[buffer(2)]],
                        constant gridUniform &gd [[buffer(3)]],
                        constant bool &volume_occlude [[buffer(4)]],
                        constant float *temperature [[buffer(5)]],
                        constant float *velocity [[buffer(6)]],
                        device simd_float2 *tempResult [[buffer(7)]],
                        device float3 *velocityResult [[buffer(8)]],
                        constant float &rotationValue [[buffer(9)]],
                        uint index [[thread_position_in_grid]]){
    
    float3 position = verticies[index];
    position = float3(float(cos(rotationValue)) * position.x + float(sin(rotationValue)) * position.z,
                      position.y,
                      -float(sin(rotationValue)) * position.x + float(cos(rotationValue)) * position.z);
    float newTemp = 0.0;
    float3 newVel = simd_float3(0.0,0.0,0.0);
    
    float P1 = boundary_points[1];
    float P3 = boundary_points[3];
    
    int ind_x = int(float(gd.gridSizeX)*(position.x - P1)/gd.gridLengthX);
    int ind_y = int(float(gd.gridSizeY)*(position.y - gd.pc_min_y)/gd.gridLengthY);
    int ind_z = int(float(gd.gridSizeZ)*(position.z - P3)/gd.gridLengthZ);
    
    if (ind_x >= gd.gridSizeX){
        ind_x = gd.gridSizeX-1;
    }
    if (ind_y >= gd.gridSizeY){
        ind_y = gd.gridSizeY-1;
    }
    if (ind_z >= gd.gridSizeZ){
        ind_z = gd.gridSizeZ-1;
    }
    if (ind_x < 0){
        ind_x = 0;
    }
    if (ind_y < 0){
        ind_y = 0;
    }
    if (ind_z < 0){
        ind_z = 0;
    }
    
    float max_x = position.x;
    float min_x = position.x;
    float max_y = position.y;
    float min_y = position.y;
    float max_z = position.z;
    float min_z = position.z;

    int ind_max_x = ind_x;
    int ind_max_y = ind_y;
    int ind_max_z = ind_z;

    int ind_min_x = ind_x;
    int ind_min_y = ind_y;
    int ind_min_z = ind_z;

    simd_float3 p1 = simd_float3(0,0,0);
    simd_float3 p2 = simd_float3(0,0,0);
    simd_float3 p3 = simd_float3(0,0,0);
    simd_float3 p4 = simd_float3(0,0,0);
    simd_float3 p5 = simd_float3(0,0,0);
    simd_float3 p6 = simd_float3(0,0,0);

    float t1 = 0;
    float t2 = 0;
    float t3 = 0;
    float t4 = 0;
    float t5 = 0;
    float t6 = 0;
    
    int idx_1d = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
    if(position.x >= gridArray[idx_1d].position.x && position.y >= gridArray[idx_1d].position.y && position.z >= gridArray[idx_1d].position.z){
        float min_x = gridArray[idx_1d].position.x;
        float min_y = gridArray[idx_1d].position.y;
        float min_z = gridArray[idx_1d].position.z;

        int ind_min_x = int(float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX);
        int ind_min_y = int(float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY);
        int ind_min_z = int(float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ);

        if(ind_x < gd.gridSizeX - 1){
            int new_idx = (ind_x+1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            max_x = gridArray[new_idx].position.x;
            ind_max_x += 1;
        }
        if(ind_y < gd.gridSizeY - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y+1)*gd.gridSizeZ + ind_z;
            max_y = gridArray[new_idx].position.y;
            ind_max_y += 1;
        }
        if(ind_z < gd.gridSizeZ - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + (ind_z+1);
            max_z = gridArray[new_idx].position.z;
            ind_max_z += 1;
        }
        
        // 1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;

        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        float3 min_velocity = float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];
        
        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        //2
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];
        
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
    
    else if(position.x >= gridArray[idx_1d].position.x && position.y >= gridArray[idx_1d].position.y && position.z < gridArray[idx_1d].position.z){
        min_x = gridArray[idx_1d].position.x;
        min_y = gridArray[idx_1d].position.y;
        max_z = gridArray[idx_1d].position.z;

        ind_min_x = int(float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX);
        ind_min_y = int(float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY);
        ind_max_z = int(float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ);

        if(ind_x < gd.gridSizeX - 1){
            int new_idx = (ind_x+1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            max_x = gridArray[new_idx].position.x;
            ind_max_x += 1;
        }
        if(ind_y < gd.gridSizeY - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y+1)*gd.gridSizeZ + ind_z;
            max_y = gridArray[new_idx].position.y;
            ind_max_y += 1;
        }
        if(ind_z > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + (ind_z-1);
            min_z = gridArray[new_idx].position.z;
            ind_min_z -= 1;
        }
        
        //1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;
        

        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];

        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

        //2
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

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
    
    else if(position.x >= gridArray[idx_1d].position.x && position.y < gridArray[idx_1d].position.y && position.z >= gridArray[idx_1d].position.z){
        min_x = gridArray[idx_1d].position.x;
        max_y = gridArray[idx_1d].position.y;
        min_z = gridArray[idx_1d].position.z;

        ind_min_x = int(float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX);
        ind_max_y = int(float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY);
        ind_min_z = int(float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ);

        if(ind_x < gd.gridSizeX - 1){
            int new_idx = (ind_x+1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            max_x = gridArray[new_idx].position.x;
            ind_max_x += 1;
        }
        if(ind_y > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y-1)*gd.gridSizeZ + ind_z;
            min_y = gridArray[new_idx].position.y;
            ind_min_y -= 1;
        }
        if(ind_z < gd.gridSizeZ - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + (ind_z+1);
            max_z = gridArray[new_idx].position.z;
            ind_max_z += 1;
        }
        
        //1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;

        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];

        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

        //2
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];
        
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

        ind_min_x = int(float(gd.gridSizeX)*(min_x - P1)/gd.gridLengthX);
        ind_max_y = int(float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY);
        ind_max_z = int(float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ);

        if(ind_x < gd.gridSizeX - 1){
            int new_idx = (ind_x+1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            max_x = gridArray[new_idx].position.x;
            ind_max_x += 1;
        }
        if(ind_y > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y-1)*gd.gridSizeZ + ind_z;
            min_y = gridArray[new_idx].position.y;
            ind_min_y -= 1;
        }
        if(ind_z > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + (ind_z-1);
            min_z = gridArray[new_idx].position.z;
            ind_min_z -= 1;
        }
        
        //1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;


        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];

        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        //2
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));

        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];
        
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
    
    else if(position.x < gridArray[idx_1d].position.x && position.y >= gridArray[idx_1d].position.y && position.z >= gridArray[idx_1d].position.z){
        max_x = gridArray[idx_1d].position.x;
        min_y = gridArray[idx_1d].position.y;
        min_z = gridArray[idx_1d].position.z;

        ind_max_x = int(float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
        ind_min_y = int(float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY);
        ind_min_z = int(float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ);
        
        if(ind_x > 0){
            int new_idx = (ind_x-1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            min_x = gridArray[new_idx].position.x;
            ind_min_x -= 1;
        }
        if(ind_y < gd.gridSizeY - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y+1)*gd.gridSizeZ + ind_z;
            max_y = gridArray[new_idx].position.y;
            ind_max_y += 1;
        }
        if(ind_z < gd.gridSizeZ - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ +  (ind_z+1);
            max_z = gridArray[new_idx].position.z;
            ind_max_z += 1;
        }

        //1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;
        
        
        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];

        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

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

        ind_max_x = int(float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
        ind_min_y = int(float(gd.gridSizeY)*(min_y - gd.pc_min_y)/gd.gridLengthY);
        ind_max_z = int(float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ);

        if(ind_x > 0){
            int new_idx = (ind_x-1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            min_x = gridArray[new_idx].position.x;
            ind_min_x -= 1;
        }
        if(ind_y < gd.gridSizeY - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y+1)*gd.gridSizeZ + ind_z;
            max_y = gridArray[new_idx].position.y;
            ind_max_y += 1;
        }
        if(ind_z > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + (ind_z-1);
            min_z = gridArray[new_idx].position.z;
            ind_min_z -= 1;
        }

        //1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;
        
        
        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];

        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //2
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

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

        ind_max_x = int(float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
        ind_max_y = int(float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY);
        ind_min_z = int(float(gd.gridSizeZ)*(min_z - P3)/gd.gridLengthZ);

        if(ind_x > 0){
            int new_idx = (ind_x-1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            min_x = gridArray[new_idx].position.x;
            ind_min_x -= 1;
        }
        if(ind_y > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y-1)*gd.gridSizeZ + ind_z;
            min_y = gridArray[new_idx].position.y;
            ind_min_y -= 1;
        }
        if(ind_z < gd.gridSizeZ - 1){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + (ind_z+1);
            max_z = gridArray[new_idx].position.z;
            ind_max_z += 1;
        }

        //1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;
        

        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];

        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        //2
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        
        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

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

        ind_max_x = int(float(gd.gridSizeX)*(max_x - P1)/gd.gridLengthX);
        ind_max_y = int(float(gd.gridSizeY)*(max_y - gd.pc_min_y)/gd.gridLengthY);
        ind_max_z = int(float(gd.gridSizeZ)*(max_z - P3)/gd.gridLengthZ);

        if(ind_x > 0){
            int new_idx = (ind_x-1)*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z;
            min_x = gridArray[new_idx].position.x;
            ind_min_x -= 1;
        }
        if(ind_y > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + (ind_y-1)*gd.gridSizeZ + ind_z;
            min_y = gridArray[new_idx].position.y;
            ind_min_y -= 1;
        }
        if(ind_z > 0){
            int new_idx = ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + (ind_z-1);
            min_z = gridArray[new_idx].position.z;
            ind_min_z -= 1;
        }

        //1
        float d1 = position.x - min_x;
        float d2 = max_x - position.x;

        
        int max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        float max_temperature = temperature[max_indicies];
        int min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_min_z;
        simd_float3 min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        float min_temperature = temperature[min_indicies];

        p1 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t1 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //2
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_min_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p2 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t2 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //3
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_min_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

        p3 = (d1 * max_velocity / (d1 + d2)) + (d2 * min_velocity / (d1 + d2));
        t3 = (d1 * max_temperature / (d1 + d2)) + (d2 * min_temperature / (d1 + d2));
        //4
        max_indicies = ind_max_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        max_velocity = simd_float3(velocity[max_indicies*3], velocity[max_indicies*3 + 1], velocity[max_indicies*3 + 2]);
        max_temperature = temperature[max_indicies];
        min_indicies = ind_min_x*gd.gridSizeY*gd.gridSizeZ + ind_max_y*gd.gridSizeZ + ind_max_z;
        min_velocity = simd_float3(velocity[min_indicies*3], velocity[min_indicies*3 + 1], velocity[min_indicies*3 + 2]);
        min_temperature = temperature[min_indicies];

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
    
    float2 new_temp = float2(newTemp, 1.0);
    
    if((position.y > gd.pc_max_y) || (position.y < gd.pc_min_y)){
        new_temp.y = 0.0;
    }
    
    // occlusion (ray casting)
    if(volume_occlude) {
        float3 rotEye = float3(float(cos(rotationValue)) * gd.eye.x + float(sin(rotationValue)) * gd.eye.z,
                               gd.eye.y,
                               -float(sin(rotationValue)) * gd.eye.x + float(cos(rotationValue)) * gd.eye.z);
        float3 ray_dir = normalize(position - rotEye);
        float ray_length = 0.05;
         
        float cube_length = 0.1; //gd.gridLengthX/float(gd.gridSizeX);
         
        float pointlength = sqrt(pow(position.x - gd.eye.x, 2) + pow(position.y - gd.eye.y, 2) + pow(position.z - gd.eye.z, 2));
       
        if(pointlength <= ray_length) {
            ray_length = pointlength;
        }
         
        float min_length = float(sqrt(pow(cube_length,2) + pow(cube_length,2) + pow(cube_length, 2)));
         
        int ray_num = int(pointlength/ray_length);
         
        for(int i = 1; i < ray_num; i++) {
            float3 point = rotEye + float(i)*ray_length*ray_dir;
            int ind_x = int(float(gd.gridSizeX)*(point.x - boundary_points[1])/gd.gridLengthX);
            int ind_y = int(float(gd.gridSizeY)*(point.y - gd.pc_min_y)/gd.gridLengthY);
            int ind_z = int(float(gd.gridSizeZ)*(point.z - boundary_points[3])/gd.gridLengthZ);
             
            int idx = (ind_x*gd.gridSizeY*gd.gridSizeZ + ind_y*gd.gridSizeZ + ind_z);
             
            float checklength = float(sqrt(pow(position.x - gridArray[idx].position.x,2) + pow(position.y - gridArray[idx].position.y,2) + pow(position.z - gridArray[idx].position.z, 2)));
             
            if(ind_x < gd.gridSizeX-1 && ind_x > 0 && ind_y < gd.gridSizeY-1 && ind_y > 0 && ind_z < gd.gridSizeZ-1 && ind_z > 0){
                if(gridArray[idx].occ && checklength > 1.75 * min_length){
                    new_temp.y = 0.0;
                    break;
                }
            }
        }
    }
    tempResult[index] = new_temp;
    
    newVel = float3(float(cos(-rotationValue)) * newVel.x + float(sin(-rotationValue)) * newVel.z,
                    newVel.y,
                    float(-sin(-rotationValue)) * newVel.x + float(cos(-rotationValue)) * newVel.z);
    
    velocityResult[index] = newVel;
}

/*
kernel void updateVertex(constant planeUniform &pp [[buffer(0)]],
                         constant gridUniform &gd [[buffer(1)]],
                         constant int &plane_idx [[buffer(2)]],
                         constant float *boundary_points[[buffer(3)]],
                         device cubel *verticies [[buffer(4)]],
                         uint2 index [[thread_position_in_grid]]){
    
    float x_multiplier = 0.12;
    float y_multiplier = 0.09;
    
    float3 new_p0 = pp.p0 + (-1 * pp.U*x_multiplier*float(plane_idx) - pp.V*y_multiplier*float(plane_idx));
    float3 new_p1 = pp.p1 + (pp.U*x_multiplier*float(plane_idx) - pp.V*y_multiplier*float(plane_idx));
    float3 new_p2 = pp.p2 + (-1 * pp.U*x_multiplier*float(plane_idx) + pp.V*y_multiplier*float(plane_idx));
    
    float3 x_inc = (new_p1 - new_p0)/float(volume_spacing);
    float3 y_inc = (new_p2 - new_p0)/float(volume_spacing);

    float3 p0 = new_p0 + x_inc*float(index.x) + (y_inc)*float(index.y) + pp.AT*float(plane_idx);
    float3 p1 = new_p0 + x_inc*float(index.x+1) + (y_inc)*float(index.y) + pp.AT*float(plane_idx);
    float3 p2 = new_p0 + x_inc*float(index.x) + (y_inc)*float(index.y+1) + pp.AT*float(plane_idx);
    float3 p3 = new_p0 + x_inc*float(index.x+1) + (y_inc)*float(index.y+1) + pp.AT*float(plane_idx);
        
    cubel new_cube;
    new_cube.p0 = p0;
    new_cube.p1 = p1;
    new_cube.p2 = p2;
    new_cube.p3 = p2;
    new_cube.p4 = p1;
    new_cube.p5 = p3;
    
    int idx = index.y*volume_spacing + index.x;
    verticies[idx] = new_cube;
}
*/

kernel void updateVertex(constant planeUniform &pp [[buffer(0)]],
                         constant gridUniform &gd [[buffer(1)]],
                         constant float *boundary_points[[buffer(2)]],
                         device cubel *verticies [[buffer(3)]],
                         uint3 index [[thread_position_in_grid]]){
    
    float x_multiplier = 0.12;
    float y_multiplier = 0.09;
    
    float3 new_p0 = pp.p0 + (-1 * pp.U*x_multiplier*float(index.z) - pp.V*y_multiplier*float(index.z));
    float3 new_p1 = pp.p1 + (pp.U*x_multiplier*float(index.z) - pp.V*y_multiplier*float(index.z));
    float3 new_p2 = pp.p2 + (-1 * pp.U*x_multiplier*float(index.z) + pp.V*y_multiplier*float(index.z));
    
    float3 x_inc = (new_p1 - new_p0)/float(volume_spacing);
    float3 y_inc = (new_p2 - new_p0)/float(volume_spacing);

    float3 p0 = new_p0 + x_inc*float(index.x) + (y_inc)*float(index.y) + pp.AT*float(index.z);
    float3 p1 = new_p0 + x_inc*float(index.x+1) + (y_inc)*float(index.y) + pp.AT*float(index.z);
    float3 p2 = new_p0 + x_inc*float(index.x) + (y_inc)*float(index.y+1) + pp.AT*float(index.z);
    float3 p3 = new_p0 + x_inc*float(index.x+1) + (y_inc)*float(index.y+1) + pp.AT*float(index.z);
        
    cubel new_cube;
    new_cube.p0 = p0;
    new_cube.p1 = p1;
    new_cube.p2 = p2;
    new_cube.p3 = p2;
    new_cube.p4 = p1;
    new_cube.p5 = p3;
    
    int idx = index.z*volume_spacing*volume_spacing + index.y*volume_spacing + index.x;
    verticies[idx] = new_cube;
}




