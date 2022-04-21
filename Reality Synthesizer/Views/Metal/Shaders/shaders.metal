//
//  shaders.metal
//  Reality Synthesizer
//
//  Created by Tony Morales on 4/2/22.
//

#include <metal_stdlib>

using namespace metal;


typedef struct
{
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;



// Display a 2D texture.
vertex ColorInOut planeVertexShader(Vertex in [[stage_in]])
{
    ColorInOut out;
    out.position = float4(in.position, 0.0f, 1.0f);
    out.texCoord = in.texCoord;
    return out;
}

// Shade a 2D plane by passing through the texture inputs.
fragment float4 planeFragmentShader(ColorInOut in [[stage_in]], texture2d<float, access::sample> textureIn [[ texture(0) ]])
{
    constexpr sampler colorSampler(address::clamp_to_edge, filter::linear);
    float4 sample = textureIn.sample(colorSampler, in.texCoord);
    return sample;
}

// Convert a color value to RGB using a Jet color scheme.
static half4 getJetColorsFromNormalizedVal(half val) {
    half4 res ;
    if(val <= 0.01h)
        return half4();
    res.r = 1.5h - fabs(4.0h * val - 3.0h);
    res.g = 1.5h - fabs(4.0h * val - 2.0h);
    res.b = 1.5h - fabs(4.0h * val - 1.0h);
    res.a = 1.0h;
    res = clamp(res,0.0h,1.0h);
    return res;
}

// Shade a texture with depth values using a Jet color scheme.
//- Tag: planeFragmentShaderDepth
fragment half4 planeFragmentShaderDepth(
                                        ColorInOut in [[stage_in]],
                                        texture2d<float, access::sample> textureDepth [[ texture(0) ]],
                                        constant float &minDepth [[buffer(0)]],
                                        constant float &maxDepth [[buffer(1)]])
{
    constexpr sampler colorSampler(address::clamp_to_edge, filter::nearest);
    float val = (textureDepth.sample(colorSampler, in.texCoord).r/* - minDepth*/)/(maxDepth-minDepth);
    half4 rgbaResult = getJetColorsFromNormalizedVal(half(val));
    
    if(val < minDepth || val > maxDepth)
    {
        rgbaResult = 0 ;
    }
    return rgbaResult;
}

fragment half4 planeFragmentShaderColor(ColorInOut in [[stage_in]],
                                        texture2d<half> colorYtexture [[ texture(0) ]],
                                        texture2d<half> colorCbCrtexture [[ texture(1) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    half y = colorYtexture.sample(textureSampler, in.texCoord).r;
    half2 uv = colorCbCrtexture.sample(textureSampler, in.texCoord).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    
    
    return rgbaResult;
}

// MARK: - Radiate

fragment half4 planeFragmentShaderColorRadiate(ColorInOut in [[stage_in]],
                                               texture2d<half> colorYTexture [[ texture(0) ]],
                                               texture2d<half> colorCbCrTexture [[ texture(1) ]],
                                               texture2d<float> depthTexture [[ texture(2) ]],
                                               constant float *depths [[buffer(0)]],
                                               constant int &depthsCount [[ buffer(1) ]],
                                               constant float *notes [[ buffer(2) ]],
                                               constant float *noteWidths [[ buffer(3) ]]
                                               )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    half y = colorYTexture.sample(textureSampler, in.texCoord).r;
    half2 uv = colorCbCrTexture.sample(textureSampler, in.texCoord).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;

    for (int i = 0; i < depthsCount; ++i )
    {
        if(depth > (depths[i] - noteWidths[i]) && depth < (depths[i] + noteWidths[i]))
        {
            half note = notes[i];
            rgbaResult.x = rgbaResult.z / fmod(note, 5);
            rgbaResult.y = rgbaResult.x * (fmod(note, 9) * 0.5);
            rgbaResult.z = rgbaResult.y * (fmod(note, 7) * 0.5);
        }
    }
    return rgbaResult;
}

// MARK: - Cycle

fragment half4 planeFragmentShaderColorCycle(ColorInOut in [[stage_in]],
                                             texture2d<half> colorYTexture [[ texture(0) ]],
                                             texture2d<half> colorCbCrTexture [[ texture(1) ]],
                                             texture2d<float> depthTexture [[ texture(2) ]],
                                             constant float *times [[buffer(0)]],
                                             constant float *notes [[ buffer(1) ]],
                                             constant int &notesCount [[ buffer(2) ]]
                                             )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    half y = colorYTexture.sample(textureSampler, in.texCoord).r;
    half2 uv = colorCbCrTexture.sample(textureSampler, in.texCoord).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;

    for (int i = 0; i < notesCount; ++i )
    {
        float index = fmod(notes[i], 7);
        float depthMod = fmod(depth, 20);
        rgbaResult.x = (rgbaResult.x * index / depthMod - (times[i] / 50) * sin(times[i] / 100 * index));
        rgbaResult.y = (rgbaResult.y - index / depthMod + (times[i] / 50)) * tan(times[i] / 100 - index);
        rgbaResult.z = (rgbaResult.z * index * depthMod + (times[i] / 50)) * cos(times[i] / 100 + index);
    }
    return rgbaResult;
}

// MARK: - Crazy

fragment half4 planeFragmentShaderColorCrazy(ColorInOut in [[stage_in]],
                                             texture2d<half> colorYTexture [[ texture(0) ]],
                                             texture2d<half> colorCbCrTexture [[ texture(1) ]],
                                             texture2d<float> depthTexture [[ texture(2) ]],
                                             constant float *times [[buffer(0)]],
                                             constant float *notes [[ buffer(1) ]],
                                             constant int &notesCount [[ buffer(2) ]]
                                             )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    half y = colorYTexture.sample(textureSampler, in.texCoord).r;
    half2 uv = colorCbCrTexture.sample(textureSampler, in.texCoord).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;

    half3 colors[] = {
        half3(0.2, 0.0, 0.0),
        half3(1.0, 0.0, 0.0),
        half3(0.0, 1.0, 0.0),
        half3(0.3, 0.3, 0.6),
        half3(0.0, 0.0, 0.8),
        half3(1.0, 0.0, 0.8),
        half3(0.0, 1.0, 0.8),
        half3(0.0, 0.0, 1.0),
    };
    
    for (int i = 0; i < notesCount; ++i )
    {
        float index = fmod(notes[i], 7) + 1;
        float depthMod = fmod(times[i] / 100, index);
        
        if (depth > (index) && depth < (depthMod + index))
        {
            float color = (rgbaResult.x + rgbaResult.y + rgbaResult.z) / 2.0 * times[i] / 50;
            int index = int(color * 3.0);
            rgbaResult.xyz = colors[index].xyz;
        } else if (depth > (index / 2) && depth < (index * 2))
        {
            rgbaResult.x = (1 - rgbaResult.x + (times[i] / 700));
        } else {
            rgbaResult.x = fmod(depth, depthMod) * rgbaResult.x / cos(times[i] / 100);
            rgbaResult.y = fmod(depthMod, depth) / rgbaResult.y / sin(times[i] / 100);
            rgbaResult.z = fmod(index, depth) + rgbaResult.z / tan(times[i] / 100);
        }
    }
    return rgbaResult;
}

fragment half4 planeFragmentShaderColorZap(ColorInOut in [[stage_in]],
                                           texture2d<half> colorYTexture [[ texture(0) ]],
                                           texture2d<half> colorCbCrTexture [[ texture(1) ]],
                                           texture2d<float> depthTexture [[ texture(2) ]],
                                           constant float &minDepth [[buffer(0)]],
                                           constant float &maxDepth [[buffer(1)]],
                                           constant float &globalMaxDepth [[buffer(2)]]
                                           )
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    half y = colorYTexture.sample(textureSampler, in.texCoord).r;
    half2 uv = colorCbCrTexture.sample(textureSampler, in.texCoord).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;
    if(depth > minDepth && depth < maxDepth)
    {
        half normDepth = (depth-minDepth)/(globalMaxDepth-minDepth);
        rgbaResult = rgbaResult * 0.5 + 0.5 * getJetColorsFromNormalizedVal(normDepth);
    }
    else if (depth>maxDepth && depth < maxDepth*1.1  )
    {
        rgbaResult = rgbaResult * 2 ;
        
    }
    return rgbaResult;
}


// Shade a texture with confidence levels low, medium, and high to red, green, and blue, respectively.
fragment half4 planeFragmentShaderConfidence(ColorInOut in [[stage_in]], texture2d<float, access::sample> textureIn [[ texture(0) ]])
{
    constexpr sampler colorSampler(address::clamp_to_edge, filter::nearest);
    float4 s = textureIn.sample(colorSampler, in.texCoord);
    float res = round( 255.0f*(s.r) ) ;
    int resI = int(res);
    half4 color = half4(0.0h, 0.0h, 0.0h, 0.0h);
    if (resI == 0)
        color = half4(1.0h, 0.0h, 0.0h, 1.0h);
    else if (resI == 1)
        color = half4(0.0h, 1.0h, 0.0h, 1.0h);
    else if (resI == 2)
        color = half4(0.0h, 0.0h, 1.0h, 1.0h);
    return color;
}


// Declare a particle class that the `pointCloudVertexShader` inputs
// to `pointCloudFragmentShader`.
typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 coor;
    float pSize [[point_size]];
    float depth;
    half4 color;
} ParticleVertexInOut;

// MARK: - Wave

// Position vertices for the point cloud view. Filters out points with
// confidence below the selected confidence value and calculates the color of a
// particle using the color Y and CbCr per vertex. Use `viewMatrix` and
// `cameraIntrinsics` to calculate the world point location of each vertex in
// the depth map.
//- Tag: pointCloudVertexShader
vertex ParticleVertexInOut pointCloudVertexWaveShader(
                                                      uint vertexID [[ vertex_id ]],
                                                      texture2d<float, access::read> depthTexture [[ texture(0) ]],
                                                      constant float4x4& viewMatrix [[ buffer(0) ]],
                                                      constant float3x3& cameraIntrinsics [[ buffer(1) ]],
                                                      constant float *depths [[buffer(2)]],
                                                      constant int &depthsCount [[ buffer(3) ]],
                                                      constant float *notes [[ buffer(4) ]],
                                                      texture2d<half> colorYtexture [[ texture(1) ]],
                                                      texture2d<half> colorCbCrtexture [[ texture(2) ]]
                                                      )
{ // ...
    ParticleVertexInOut out;
    uint2 pos;
    // Count the rows that are depth-texture-width wide to determine the y-value.
    pos.y = vertexID / depthTexture.get_width();
    
    // The x-position is the remainder of the y-value division.
    pos.x = vertexID % depthTexture.get_width();
    //get depth in [mm]
    float depth = (depthTexture.read(pos).x) * 1000.0f;
    
    
    // Calculate the vertex's world coordinates.
    float xrw = ((int)pos.x - cameraIntrinsics[2][0]) * depth / cameraIntrinsics[0][0];
    float yrw = ((int)pos.y - cameraIntrinsics[2][1]) * depth / cameraIntrinsics[1][1];
    
    float megaDepth = depth / 1000.0f;
    
    for (int i = 0; i < depthsCount; ++i )
    {
        if(megaDepth > (depths[i] - 1.57) && megaDepth < (depths[i] + 1.57))
        {
            half note = notes[i];
            xrw = xrw - (100 * cos(megaDepth - depths[i]) * (2 / (note / 40)));
        }
    }
    
    float4 xyzw = { xrw, yrw, depth, 1.f };
    
    // Project the coordinates to the view.
    float4 vecout = viewMatrix * xyzw;
    
    // Color the vertex.
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    out.coor = { pos.x / (depthTexture.get_width() - 1.0f), pos.y / (depthTexture.get_height() - 1.0f) };
    half y = colorYtexture.sample(textureSampler, out.coor).r;
    half2 uv = colorCbCrtexture.sample(textureSampler, out.coor).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    
    out.color = rgbaResult;
    out.clipSpacePosition = vecout;
    out.depth = depth;
    // Set the particle display size.
    out.pSize = 10.0f;
    
    return out;
}


// Position vertices for the point cloud view. Filters out points with
// confidence below the selected confidence value and calculates the color of a
// particle using the color Y and CbCr per vertex. Use `viewMatrix` and
// `cameraIntrinsics` to calculate the world point location of each vertex in
// the depth map.
//- Tag: pointCloudVertexShader
vertex ParticleVertexInOut pointCloudEffectVertexShader(
                                                        uint vertexID [[ vertex_id ]],
                                                        texture2d<float, access::read> depthTexture [[ texture(0) ]],
                                                        constant float4x4& viewMatrix [[ buffer(0) ]],
                                                        constant float3x3& cameraIntrinsics [[ buffer(1) ]],
                                                        constant uint& iTime [[ buffer(2) ]],
                                                        texture2d<half> colorYtexture [[ texture(1) ]],
                                                        texture2d<half> colorCbCrtexture [[ texture(2) ]]
                                                        )
{ // ...
    ParticleVertexInOut out;
    uint2 pos;
    // Count the rows that are depth-texture-width wide to determine the y-value.
    pos.y = vertexID / depthTexture.get_width();
    
    // The x-position is the remainder of the y-value division.
    pos.x = vertexID % depthTexture.get_width();
    //get depth in [mm]
    float depth = (depthTexture.read(pos).x) * 1000.0f;
    
    
    // Calculate the vertex's world coordinates.
    float xrw = ((int)pos.x - cameraIntrinsics[2][0]) * depth / cameraIntrinsics[0][0];
    float yrw = ((int)pos.y - cameraIntrinsics[2][1]) * depth / cameraIntrinsics[1][1];
    float3 xyz = { xrw, yrw, depth};
    
    // vertexID to linear random line
    float3 d = normalize(float3(sin(vertexID/2.),cos(vertexID/2.),sin(vertexID/2.)));
    //sin iTime
    float s = sin(iTime/100.0f);
    if(s <= 0)
    {
        s = 0;
    }
    float4 distXYZw = float4(xyz + 100*s* d,1.0f);
    
    // Project the coordinates to the view.
    float4 vecout = viewMatrix * distXYZw;
    
    // Color the vertex.
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    out.coor = { pos.x / (depthTexture.get_width() - 1.0f), pos.y / (depthTexture.get_height() - 1.0f) };
    half y = colorYtexture.sample(textureSampler, out.coor).r;
    half2 uv = colorCbCrtexture.sample(textureSampler, out.coor).rg - half2(0.5h, 0.5h);
    // Convert YUV to RGB inline.
    half4 rgbaResult = half4(y + 1.402h * uv.y, y - 0.7141h * uv.y - 0.3441h * uv.x, y + 1.772h * uv.x, 1.0h);
    
    out.color = rgbaResult;
    out.clipSpacePosition = vecout;
    out.depth = depth;
    // Set the particle display size.
    out.pSize = 5.0f;
    
    return out;
}

// Shade the point cloud points by using quad particles.
fragment half4 pointCloudFragmentShader(
                                        ParticleVertexInOut in [[stage_in]])
{
    // Avoid drawing particles that are too close, or filtered particles that
    // have zero depth.
    if (in.depth < 1.0f)
        discard_fragment();
    else
    {
        return in.color;
    }
    return half4();
}


// Convert the Y and CbCr textures into a single RGBA texture.
kernel void convertYCbCrToRGBA(texture2d<float, access::read> colorYtexture [[texture(0)]],
                               texture2d<float, access::read> colorCbCrtexture [[texture(1)]],
                               texture2d<float, access::write> colorRGBTexture [[texture(2)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float y = colorYtexture.read(gid).r;
    float2 uv = colorCbCrtexture.read(gid / 2).rg;
    
    const float4x4 ycbcrToRGBTransform = float4x4(
                                                  float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                  float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                  float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                  float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
                                                  );
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture
    // coordinate.
    float4 ycbcr = float4(y, uv.x, uv.y, 1.0f);
    
    // Return the converted RGB color.
    float4 colorSample = ycbcrToRGBTransform * ycbcr;
    colorRGBTexture.write(colorSample, uint2(gid.xy));
    
}

