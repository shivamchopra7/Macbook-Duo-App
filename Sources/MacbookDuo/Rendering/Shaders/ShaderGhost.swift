import Foundation

/// Ghost: the desktop stays anchored behind the tilting physical panel.
enum ShaderGhost {
    static let function = #"""
    // ---------------------------------------------------------------- Ghost
    // Intersect a stationary viewer's ray through the moving panel with the
    // original desktop plane. The hinge stays fixed; panel pixels compensate
    // for tilt so the desktop appears anchored behind the physical display.
    // Fix the viewer relative to the keyboard, not to each new resting screen.
    static float4 foldGhost(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                            sampler s, constant Uniforms& u, float p) {
        float height = 1.0f-uv.y;
        float perspective = clamp(u.perspective,0.0f,1.0f);
        float viewerDistance = mix(2.6f,1.6f,perspective);
        // Shallow resting angles use an upright virtual plane: a real viewer
        // may otherwise lie behind it. This continuous fallback keeps eyeZ >= 1.6.
        float reference = clamp(u.referenceAngle,90.0f,140.0f)*M_PI_F/180.0f;
        float eyeY = 1.6f*sin(reference)+viewerDistance*cos(reference);
        float eyeZ = viewerDistance*sin(reference)-1.6f*cos(reference);
        float angle = clamp(u.tilt >= 0 ? u.tilt : p*M_PI_F*0.5f,0.0f,85.0f*M_PI_F/180.0f);
        float depth = height*sin(angle);
        float rayScale = eyeZ/(eyeZ-depth);
        float2 sourceUV = float2(0.5f+(uv.x-0.5f)*rayScale,
                                1.0f-(eyeY+(height*cos(angle)-eyeY)*rayScale));
        // Ease the first 1.7 degrees without a pixel jump from exact passthrough.
        float onset = clamp(angle/0.03f,0.0f,1.0f);
        onset = onset*onset*onset*(onset*(onset*6.0f-15.0f)+10.0f);
        sourceUV = mix(uv,sourceUV,onset);
        float focus = u.defocus >= 0 ? pow(clamp(u.defocus,0.0f,1.0f),1.25f) : p*p;
        // Defocus measures distance from the hinge, while the onset remains
        // gentle for the first few degrees, independent of the resting angle.
        float separation = pow(height,1.65f);
        float sigmaUV = clamp(u.blur,0.0f,1.0f)*0.045f*focus*separation;
        // Tilt slightly minifies fine content even with user defocus off.
        sigmaUV = max(sigmaUV,0.5f*max(0.0f,rayScale-1.0f)/float(desktop.get_height()));
        float3 color = foldSample(desktop,pyramid,s,sourceUV,sigmaUV);
        // Soften the exposed sides along with the content, instead of cutting
        // a sharp trapezoid out of an already blurred image. At zero tilt the
        // exact-passthrough branch retains every original edge pixel.
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        float2 feather = max(float2(3.0f*sigmaUV/aspect,3.0f*sigmaUV),fwidth(sourceUV));
        float2 border = smoothstep(-feather,feather,sourceUV)
                       *(1.0f-smoothstep(1.0f-feather,1.0f+feather,sourceUV));
        float edgeCoverage = mix(1.0f,border.x*border.y,smoothstep(0.0f,0.025f,angle));
        float shade = 1.0f-clamp(u.shadow,0.0f,1.0f)*0.10f*focus*height;
        float disappear = 1.0f-smoothstep(0.86f,1.0f,p);
        return float4(color*shade*edgeCoverage*disappear,1);
    }
    """#
}
