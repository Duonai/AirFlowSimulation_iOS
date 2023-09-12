//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "ShaderTypes.h"
#import <simd/simd.h>
#import <stdbool.h>

typedef struct {
  matrix_float4x4 modelMatrix;
  matrix_float4x4 viewMatrix;
  matrix_float4x4 projectionMatrix;
} Uniforms;

typedef struct {
    int gridSizeX;
    int gridSizeY;
    int gridSizeZ;
    simd_float3 eye;
    float pc_max_y;
    float pc_min_y;
    float gridLengthX;
    float gridLengthY;
    float gridLengthZ;
} gridUniform;

typedef struct {
    int pointCount;
    bool occ;
    bool fixed;
    simd_float3 position;
} Grid;

typedef struct {
    simd_float3 p0;
    simd_float3 p1;
    simd_float3 p2;
    simd_float3 p3;
    simd_float3 p4;
    simd_float3 p5;
} cubel;

typedef struct {
    simd_float3 AT;
    simd_float3 U;
    simd_float3 V;
    simd_float3 p0;
    simd_float3 p1;
    simd_float3 p2;
    simd_float3 p3;
} planeUniform;







