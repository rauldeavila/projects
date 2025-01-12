#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]], constant float2 *vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0.0, 1.0);
    out.texCoord = vertices[vertexID];
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]], texture2d<float> inputTexture [[texture(0)]], sampler inputSampler [[sampler(0)]]) {
    constexpr float3x3 kernel = float3x3(
        0.0, -1.0, 0.0,
        -1.0, 4.0, -1.0,
        0.0, -1.0, 0.0
    );

    float2 uv = in.texCoord;
    float2 resolution = float2(inputTexture.get_width(), inputTexture.get_height());

    // Curved screen effect
    uv = uv * 2.0 - 1.0;
    uv *= float2(1.1, 1.2);
    uv = uv * 0.5 + 0.5;

    // Scanlines effect
    float scanline = sin(uv.y * resolution.y * 0.5) * 0.1;
    float4 color = inputTexture.sample(inputSampler, uv);
    color.rgb -= scanline;

    // Noise effect
    float noise = (rand() % 100) / 100.0 * 0.05;
    color.rgb += noise;

    // Flicker effect
    float flicker = sin(uv.y * resolution.y * 0.1) * 0.05;
    color.rgb += flicker;

    return color;
}
