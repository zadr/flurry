#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 projectionMatrix;
};

struct VertexIn {
    float2 position;
    float4 color;
    float2 texCoord;
};

struct VertexOutTextured {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
};

struct VertexOutUntextured {
    float4 position [[position]];
    float4 color;
};

vertex VertexOutTextured vertex_textured(const device VertexIn *vertices [[buffer(0)]],
                                         constant Uniforms &uniforms [[buffer(1)]],
                                         uint vid [[vertex_id]]) {
    VertexOutTextured out;
    float4 pos = float4(vertices[vid].position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * pos;
    out.color = vertices[vid].color;
    out.texCoord = vertices[vid].texCoord;
    return out;
}

fragment float4 fragment_textured(VertexOutTextured in [[stage_in]],
                                  texture2d<float> tex [[texture(0)]],
                                  sampler samp [[sampler(0)]]) {
    float2 sample = tex.sample(samp, in.texCoord).rg;
    float4 result = float4(sample.r * in.color.rgb, sample.g * in.color.a);
    if (result.a <= 0.0) {
        discard_fragment();
    }
    return result;
}

vertex VertexOutUntextured vertex_untextured(const device VertexIn *vertices [[buffer(0)]],
                                              constant Uniforms &uniforms [[buffer(1)]],
                                              uint vid [[vertex_id]]) {
    VertexOutUntextured out;
    float4 pos = float4(vertices[vid].position, 0.0, 1.0);
    out.position = uniforms.projectionMatrix * pos;
    out.color = vertices[vid].color;
    return out;
}

fragment float4 fragment_untextured(VertexOutUntextured in [[stage_in]]) {
    return in.color;
}
