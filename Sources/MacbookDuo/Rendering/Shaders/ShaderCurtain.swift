import Foundation

/// Curtain: two pleated drapes draw together from the sides toward the centre.
enum ShaderCurtain {
    static let function = #"""
    // ---------------------------------------------------------------- Curtain
    // Two drapes, one per side, slide their leading edges from the screen edges
    // to the centre, meeting at p = 0.85. Each drape lays N = segments sinusoidal
    // pleats across its visible width and carries the desktop it has swept,
    // compressed by an overall gather that grows with progress and intensity and
    // bunched per pleat by the sine, so it reads as gathered cloth rather than a
    // wipe. Pleat flanks alternate light and dark, the hem drops a soft shadow on
    // the bare desktop beside it, and the top scallops between the rings.
    static float4 foldCurtain(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                              sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float inten = clamp(u.intensity,0.0f,1.0f);
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        float pleats = float(clamp(u.segments,2u,8u));
        float amp = 0.4f+1.2f*inten;                 // 1 at the original tuning
        float draw = clamp(p/0.85f,0.0f,1.0f);       // leading edges meet at p = 0.85
        float focus = u.defocus >= 0 ? u.defocus : p;
        float relief = shad*smoothstep(0.0f,0.10f,p);
        float feather = 1.5f/max(u.size.y,1.0f)+0.003f*soft;
        float edge = draw*(0.5f+2.0f*feather/aspect);
        bool right = uv.x > 0.5f;
        float x = right ? 1.0f-uv.x : uv.x;          // distance from the near screen edge

        // Bare desktop, in the shadow the hem drops just beyond the leading edge.
        float3 bare = desktop.sample(s,uv).rgb;
        float gap = max(0.0f,x-edge)*aspect;
        bare *= 1.0f-relief*0.55f*exp(-gap/(0.012f+0.035f*soft));

        // Cloth: t runs from the screen edge (0) to the leading edge (1). The
        // inverse map integrates a per-pleat density gather*(1+w*cos), which
        // stays monotonic while w < 1, so the fabric never folds over itself.
        float t = x/max(edge,1e-5f);
        float k = 2.0f*M_PI_F*pleats;
        float phase = k*t;
        float gather = 1.0f+(0.35f+0.7f*inten)*draw;
        float w = 0.55f*amp*draw;
        float sx = gather*(x+edge*w*sin(phase)/k);
        float density = gather*(1.0f+w*cos(phase));
        float drop = persp*draw*(0.006f+0.030f*amp*(0.5f-0.5f*cos(phase)));
        float sy = (uv.y-drop)/max(1.0f-drop,1e-3f);
        float2 src = float2(right ? 1.0f-sx : sx,sy);
        float minify = 0.5f*sqrt(max(density*density-1.0f,0.0f))/max(u.size.y,1.0f);
        float sigmaUV = minify+soft*0.028f*focus*clamp(density-1.0f,0.0f,1.0f);
        float3 cloth = foldSample(desktop,pyramid,s,src,sigmaUV);
        float lit = 1.0f+relief*0.30f*amp*draw*cos(phase);
        float gloss = relief*0.12f*draw*pow(max(0.0f,cos(phase-0.6f)),12.0f);
        float hem = 1.0f-relief*0.35f*exp(-(1.0f-t)*edge*aspect/(0.006f+0.015f*soft));
        cloth = min(cloth*lit*hem+gloss,float3(1.0f));

        // Above the scalloped top the shadowed desktop shows through.
        float onCloth = smoothstep(0.0f,feather/aspect,edge-x)*smoothstep(0.0f,feather,uv.y-drop);
        float3 color = mix(bare,cloth,onCloth);
        return float4(color*(1.0f-smoothstep(0.88f,1.0f,p)),1);
    }
    """#
}
