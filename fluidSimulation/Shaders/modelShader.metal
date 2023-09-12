//
//  modelShader.metal
//  fluidSimulation
//
//  Created by Donghan Kim on 2022/02/19.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

enum {
    textureIndexBaseColor,
    textureIndexMetallic,
    textureIndexRoughness,
    textureIndexNormal,
    textureIndexEmissive,
    textureIndexIrradiance = 9
};
    
struct objVertexIn {
    float3 position [[ attribute(0) ]];
    float3 normal [[ attribute(1) ]];
    float2 textCoord [[ attribute(2) ]];
};

struct objVertexOut {
    float4 position [[ position ]];
    float3 normal;
    float3 v_view;
    float4 color;
    float2 textCoord;
};

struct primVertIn {
    simd_float3 position [[ attribute(0) ]];
    simd_float3 normal [[ attribute(1) ]];
    simd_float4 color [[ attribute(2) ]];
};

struct primVertOut {
    simd_float4 position [[ position ]];
    simd_float4 color;
};

struct particleVertOut {
    simd_float4 position [[ position ]];
    float pointSize [[point_size]];
    simd_float4 color;
};
    
struct ParticleFragmentOut {
    float depth [[depth(any)]];
    float4 color;
};

vertex particleVertOut particle_shader(const primVertIn vertIn [[ stage_in ]],
                                       constant CameraUniforms &uniforms [[ buffer(1) ]],
                                       constant simd_float4x4 &modelMat [[ buffer(2) ]]) {
    
    simd_float4 position = uniforms.projectionMatrix * uniforms.viewMatrix * modelMat * float4(vertIn.position, 1.0);
    
    particleVertOut vertOut;
    vertOut.position = position;
    vertOut.pointSize = max(24.0 / max(1.0, position.z), 2.0);
    vertOut.color = vertIn.color;
    return vertOut;
}
    
fragment ParticleFragmentOut particle_shader_fragment(primVertOut in [[ stage_in ]],
                                                      const float2 coords [[point_coord]]) {
    
    const float distSquared = length_squared(coords - float2(0.5));
    if (in.color.a == 0 || distSquared > 0.25) {
        discard_fragment();
    }
    
    ParticleFragmentOut out;
    out.depth = 1.0 - in.position.z;
    out.color = in.color;
    return out;
}

vertex objVertexOut vertex_shader(const primVertIn vertIn [[ stage_in ]],
                                 constant CameraUniforms &uniforms [[ buffer(1) ]],
                                 constant simd_float4x4 &modelMat [[ buffer(2) ]],
                                 constant simd_float3 &eye_pos [[buffer(3)]] ) {
    
    objVertexOut new_vert;
    new_vert.position = uniforms.projectionMatrix * uniforms.viewMatrix * modelMat * float4(vertIn.position, 1.0);
    new_vert.normal = vertIn.normal;
    new_vert.v_view = normalize(eye_pos - vertIn.position);
    new_vert.color = vertIn.color;
    return new_vert;
}
    
fragment ParticleFragmentOut fragment_shader(objVertexOut in [[ stage_in ]],
                                constant lightUniform &light [[buffer(1)]],
                                constant int &enable [[buffer(2)]]) {
    
    ParticleFragmentOut out;
    if(enable == 1){
        float3 normal = normalize(in.normal);
        float3 normalizedView = normalize(in.v_view);
        
        // diffuse term
        float3 diff = max(dot(normal, normalizedView), 0.0) * light.lightDiffuse * in.color.rgb;
        
        // specular term
        float3 refl = 2.0 * normal * dot(normal, normalizedView) - normalizedView;
        float3 spec = pow(max(dot(refl, normalizedView), 0.0), light.materialShininess) * light.lightSpecular * light.materialSpecular;
        
        // ambient term
        float3 ambi = light.lightAmbient * light.materialAmbient;
        out.color = float4(diff + spec + ambi, in.color.w);
        out.depth = 1.0 - in.position.z;
        //return float4(diff + spec + ambi, in.color.w);
        return out;
    }
    else {
        //return in.color;
        out.color = in.color;
        out.depth = 1.0 - in.position.z;
        return out;
    }
}
    
//for volume rendering
fragment float4 fragment_volume_shader(objVertexOut in [[ stage_in ]],
                                constant lightUniform &light [[buffer(1)]],
                                constant int &enable [[buffer(2)]]) {
    
    if(enable == 1){
        float3 normal = normalize(in.normal);
        float3 normalizedView = normalize(in.v_view);
        
        // diffuse term
        float3 diff = max(dot(normal, normalizedView), 0.0) * light.lightDiffuse * in.color.rgb;
        
        // specular term
        float3 refl = 2.0 * normal * dot(normal, normalizedView) - normalizedView;
        float3 spec = pow(max(dot(refl, normalizedView), 0.0), light.materialShininess) * light.lightSpecular * light.materialSpecular;
        
        // ambient term
        float3 ambi = light.lightAmbient * light.materialAmbient;
        
        return float4(diff + spec + ambi, in.color.w);
    }
    else {
        return in.color;
    }
}

    
// MARK: - Single OBJ rendering (streamRibbon, volume, etc...)
    
vertex objVertexOut objVertex(const objVertexIn vIn [[stage_in]],
                              constant CameraUniforms &uniforms [[ buffer(1) ]],
                              constant modelUniforms &modelUniform [[ buffer(2) ]]){
    
    objVertexOut new_vert;
    new_vert.position = uniforms.projectionMatrix * uniforms.viewMatrix * modelUniform.modelMat * float4(vIn.position, 1.0);
    
    new_vert.normal = modelUniform.normalMat * vIn.normal;
    new_vert.color = modelUniform.color;
    new_vert.textCoord = vIn.textCoord;
    return new_vert;
}
    
    
// MARK: - Instance Rendering
    
vertex objVertexOut objVertexInstanced(const objVertexIn vIn [[stage_in]],
                                       uint instanceId [[instance_id]],
                                       constant CameraUniforms &uniforms [[buffer(1)]],
                                       constant modelUniforms *modelUniformArr [[ buffer(2)]],
                                       constant simd_float3 &eye_pos [[buffer(3)]]){
    
    objVertexOut new_vert;
    modelUniforms modelUniform = modelUniformArr[instanceId];
    simd_float3 worldPos = (modelUniform.modelMat * float4(vIn.position, 1.0)).xyz;
    
    new_vert.position = uniforms.projectionMatrix * uniforms.viewMatrix * modelUniform.modelMat * float4(vIn.position, 1.0);
    new_vert.normal = modelUniform.normalMat * vIn.normal;
    new_vert.v_view = normalize(eye_pos - worldPos);
    new_vert.color = modelUniform.color;
    new_vert.textCoord = vIn.textCoord;
    return new_vert;
}
    
    
fragment ParticleFragmentOut objFragment(objVertexOut in [[stage_in]],
                            texture2d<float> baseColorMap [[texture(textureIndexBaseColor)]],
                            texture2d<float> metallicMap  [[texture(textureIndexMetallic)]],
                            texture2d<float> roughnessMap [[texture(textureIndexRoughness)]],
                            texture2d<float> normalMap    [[texture(textureIndexNormal)]],
                            texture2d<float> emissiveMap  [[texture(textureIndexEmissive)]],
                            texturecube<float> irradianceMap [[texture(textureIndexIrradiance)]],
                            constant lightUniform &light [[buffer(11)]],
                            constant int &enable [[buffer(12)]]){
    
    // constexpr sampler textureSampler(filter::linear);
    // float3 baseColor = baseColorMap.sample(textureSampler, in.textCoord).rgb;
    
    ParticleFragmentOut out;
    out.depth = 1.0 - in.position.z;
    // phong shading
    if(enable == 1) {
        // normalize
        float3 normal = normalize(in.normal);
        float3 normalizedView = normalize(in.v_view);
        
        // diffuse term
        float3 diff = max(dot(normal, normalizedView), 0.0) * light.lightDiffuse * in.color.rgb;
        
        // specular term
        float3 refl = 2.0 * normal * dot(normal, normalizedView) - normalizedView;
        float3 spec = pow(max(dot(refl, normalizedView), 0.0), light.materialShininess) * light.lightSpecular * light.materialSpecular;
        
        // ambient term
        float3 ambi = light.lightAmbient * light.materialAmbient;
        out.color = float4(diff + spec + ambi, in.color.w);
    }
    else {
        out.color = in.color;
    }
    return out;

}

