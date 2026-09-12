import Foundation

/// The default fold, and the fallback for any unrecognized effect index.
enum ShaderDuo {
    static let function = #"""
    // ------------------------------------------------------------------ Duo
    static float4 foldDuo(float2 screenUV, texture2d<float> desktop, texture2d<float> pyramid,
                          sampler s, constant Uniforms& u, float p) {
        // The physical lid already supplies the camera's trapezoid. Expand the
        // image around its bottom-centre hinge so icons swell and upper content
        // leaves through the top. A bounded map avoids singularities at closure.
        float height = 1.0f-screenUV.y;
        float expansion = 1.0f+p*(0.12f+mix(0.30f,0.66f,clamp(u.perspective,0.0f,1.0f))*height);
        float2 uv = float2(0.5f+(screenUV.x-0.5f)/expansion,1.0f-height/expansion);

        // Sigma is measured as a fraction of image height, matching the preview
        // and Retina desktop. The hinge stays more focused, but not pin-sharp.
        float focus = u.defocus >= 0 ? u.defocus : pow(p,0.7f);
        float spread = 0.12f+0.88f*pow(height,1.15f);
        float sigmaUV = clamp(u.blur,0.0f,1.0f)*0.052f*focus*spread;
        float sigma = sigmaUV*float(desktop.get_height());
        // Each 2x level contributes 1.25 source-pixel variance per axis.
        float lod = 0.5f*log2(1.0f+sigma*sigma*2.4f);
        lod = min(lod,float(pyramid.get_num_mip_levels()-1));
        float3 color = pyramid.sample(s,uv,level(lod)).rgb;
        // Feather in display coordinates: zooming the source beyond its borders
        // must not remove the dark surround. Side widths use height units to keep
        // the same optical width on different display aspect ratios.
        float softness = clamp(u.blur,0.0f,1.0f);
        float topWidth = p*(0.075f+0.15f*softness)+1.5f*sigmaUV;
        float sideWidth = (p*(0.055f+0.12f*softness)+1.5f*sigmaUV)*u.size.y/u.size.x;
        float bottomWidth = p*(0.012f+0.025f*softness)+0.5f*sigmaUV;
        float mask = smoothstep(0.0f,topWidth,screenUV.y)*smoothstep(0.0f,bottomWidth,height)
                   * smoothstep(0.0f,sideWidth,screenUV.x)*smoothstep(0.0f,sideWidth,1.0f-screenUV.x);
        float shade = 1.0f-clamp(u.shadow,0.0f,1.0f)*0.12f*p*p*height;
        float disappear = 1.0f-smoothstep(0.86f,1.0f,p);
        return float4(color*mask*shade*disappear,1);
    }
    """#
}
