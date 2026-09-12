import Foundation

/// Metal source shared by every effect: the uniform and varying layouts, the
/// full-screen vertex, the blur-pyramid downsample kernel and the prefiltered
/// sampler in `header`; the effect dispatch and fragment entry in `dispatch`.
enum ShaderCommon {
    /// Declarations every effect function depends on. Must precede them.
    static let header = #"""
    #include <metal_stdlib>
    using namespace metal;
    struct Uniforms { float progress; float perspective; float blur; float shadow; float2 size; float fadeOnly; uint effect; float defocus; float coverage; float tilt; float referenceAngle; float intensity; uint segments; float2 reserved; };
    struct Varying { float4 position [[position]]; float2 uv; };

    vertex Varying foldVertex(uint id [[vertex_id]]) {
        const float2 p[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
        Varying v;
        v.position = float4(p[id],0,1);
        v.uv = float2((p[id].x+1)*0.5f,1-(p[id].y+1)*0.5f);
        return v;
    }

    // Separable binomial filter [1,4,6,4,1]/16, evaluated with nine
    // bilinear reads while halving both dimensions. No random or time-based taps.
    kernel void foldDownsample(texture2d<float, access::sample> source [[texture(0)]],
                               texture2d<float, access::write> target [[texture(1)]],
                               uint2 pixel [[thread_position_in_grid]]) {
        if (pixel.x >= target.get_width() || pixel.y >= target.get_height()) return;
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
        float2 uv = (float2(pixel)+0.5f)/float2(target.get_width(),target.get_height());
        float2 texel = 1.0f/float2(source.get_width(),source.get_height());
        const float offset[3] = {-1.2f,0,1.2f};
        const float weight[3] = {0.3125f,0.375f,0.3125f};
        float4 color = 0;
        for (uint y=0;y<3;y++) for (uint x=0;x<3;x++)
            color += source.sample(s,uv+float2(offset[x],offset[y])*texel)*weight[x]*weight[y];
        target.write(color,pixel);
    }

    // Sigma is a fraction of image height so the preview and the Retina desktop
    // agree. Zero sigma reads the untouched source, keeping the open image exact.
    static float3 foldSample(texture2d<float> desktop, texture2d<float> pyramid,
                             sampler s, float2 uv, float sigmaUV) {
        if (!(sigmaUV > 0.0f)) return desktop.sample(s,uv).rgb;
        float sigma = sigmaUV*float(desktop.get_height());
        // Each 2x level contributes 1.25 source-pixel variance per axis.
        float lod = 0.5f*log2(1.0f+sigma*sigma*2.4f);
        lod = min(lod,float(pyramid.get_num_mip_levels()-1));
        return pyramid.sample(s,uv,level(lod)).rgb;
    }
    """#

    /// Routes `Uniforms.effect` to its function, then the fragment entry point.
    /// Must follow every effect function.
    static let dispatch = #"""
    static float4 foldEffectPixel(float2 screenUV, texture2d<float> desktop,
        texture2d<float> pyramid, constant Uniforms& u) {
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
        float p = clamp(u.progress,0.0f,1.0f);
        if (p < 0.00001f) return float4(desktop.sample(s,screenUV).rgb,1);
        if (u.fadeOnly > 0.5f) return float4(desktop.sample(s,screenUV).rgb*(1-p),1);
        if (p >= 1.0f) return float4(0,0,0,1);
        if (u.effect == 5u) return foldGhost(screenUV,desktop,pyramid,s,u,p);
        if ((u.effect >= 1u && u.effect <= 4u) || (u.effect >= 6u && u.effect <= 11u)) {
            float4 result;
            if (u.effect == 1u) result = foldRoll(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 2u) result = foldShutter(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 3u) result = foldFlex(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 4u) result = foldIris(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 6u) result = foldFold(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 7u) result = foldAccordion(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 8u) result = foldLouver(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 9u) result = foldCard(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 10u) result = foldCurtain(screenUV,desktop,pyramid,s,u,p);
            else result = foldRipple(screenUV,desktop,pyramid,s,u,p);
            // Introduce the material's seams and contact shadows continuously.
            // Without this short angle-driven onset, fixed antialias widths and
            // depth shading can flash when the exact-open branch disengages.
            if (p < 0.04f) {
                result.rgb = mix(desktop.sample(s,screenUV).rgb,result.rgb,smoothstep(0.0f,0.04f,p));
            }
            return result;
        }

        return foldDuo(screenUV,desktop,pyramid,s,u,p);
    }
    fragment float4 foldFragment(Varying v [[stage_in]],
        texture2d<float> desktop [[texture(0)]], texture2d<float> pyramid [[texture(1)]],
        constant Uniforms& u [[buffer(0)]]) {
        float4 result = foldEffectPixel(v.uv,desktop,pyramid,u);
        if (u.coverage >= 1.0f) return result;
        constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
        return float4(mix(desktop.sample(s,v.uv).rgb,result.rgb,clamp(u.coverage,0.0f,1.0f)),1);
    }
    """#
}
