import Foundation

/// Louver: horizontal slats turn edge-on like closing venetian blinds.
enum ShaderLouver {
    static let function = #"""
    // ---------------------------------------------------------------- Louver
    // Venetian blinds: N slats stacked from the hinge, each turning about its own
    // horizontal axis. A slat's visible height is its band times cos(angle), so
    // the inverse map stretches the screen offset back by 1/cos and the strip
    // between neighbouring slats reveals the dark lid. Perspective lets the half
    // turning toward the viewer swell and the far half shrink, which tapers each
    // slat's sides. The top slat starts first, so closure runs as a wave to the hinge.
    static float louverSoft(float x, float w) {
        if (w <= 0.0f) return x >= 0.0f ? 1.0f : 0.0f;
        float t = clamp(x/w,0.0f,1.0f);
        return t*t*(3.0f-2.0f*t);
    }
    static float4 foldLouver(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float inten = clamp(u.intensity,0.0f,1.0f);
        float n = float(clamp(u.segments,2u,8u));
        float band = 1.0f/n, reach = 0.5f*band;
        float h = 1.0f-uv.y;
        float j = clamp(floor(h*n),0.0f,n-1.0f);
        float centre = (j+0.5f)*band;
        float sy = h-centre;

        // The slat at the top begins at once, the one at the hinge a tenth of
        // the closure later; intensity scales how fast every slat turns.
        float delay = 0.10f*(1.0f-centre);
        float q = clamp((p-delay)/(0.9f-delay),0.0f,1.0f);
        float theta = min(q*mix(0.6f,1.5f,inten)*1.4835f,1.5184f);
        float ct = cos(theta), st = sin(theta);

        // Material at axis distance t lands at screen offset t*cos/(1-t*kp):
        // the near half is magnified, the far half shrunk. Exact for kp=0.
        float kp = 0.07f*persp*st/reach;
        float nearEdge = reach*ct/(1.0f-reach*kp);
        float farEdge = -reach*ct/(1.0f+reach*kp);
        float gap = band-(nearEdge-farEdge);
        float feather = min(0.0016f+0.004f*soft,0.5f*gap);
        float cover = louverSoft(min(nearEdge-sy,sy-farEdge),feather);
        float t = sy/max(ct+sy*kp,1e-4f);
        float scale = 1.0f-t*kp;
        float2 src = float2(0.5f+(uv.x-0.5f)*scale,1.0f-(centre+t));
        // Sides only taper where the far half has pulled in from the screen edge.
        float inset = 0.5f-0.5f/max(scale,1e-3f);
        float fx = min(feather*u.size.y/max(u.size.x,1.0f),max(inset,0.0f));
        cover *= louverSoft(uv.x-inset,fx)*louverSoft(1.0f-inset-uv.x,fx);

        // Compressing the band into its visible height minifies the source;
        // optical defocus grows with the slat angle on top of that.
        float defocus = u.defocus >= 0.0f ? u.defocus : 1.0f;
        float sigmaUV = min(0.45f*(1.0f/ct-1.0f)/float(desktop.get_height())
                          + soft*0.022f*defocus*st*st,0.03f);
        float3 color = foldSample(desktop,pyramid,s,src,sigmaUV);
        // Edge-on slats go dark; the half turned toward the viewer catches the
        // light and its leading edge carries a thin specular line.
        float lit = (1.0f-shad*0.55f*(1.0f-ct))*(1.0f+shad*0.28f*st*t/reach);
        float gloss = (0.14f+0.34f*shad)*st*exp(-max(nearEdge-sy,0.0f)/(0.004f+0.008f*soft));
        color = min(color*lit+gloss,float3(1.0f))*cover;
        return float4(color*(1.0f-smoothstep(0.88f,1.0f,p)),1);
    }
    """#
}
