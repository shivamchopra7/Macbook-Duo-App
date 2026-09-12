import Foundation

/// Shutter: rigid equal-height panels telescope toward the hinge.
enum ShaderShutter {
    static let function = #"""
    // ------------------------------------------------------------- Shutter
    // `segments` equal-height panels (four by default), each a pure translation
    // of its own band, so pixels inside a panel stay rigid. Front to back: the
    // first panel that covers the pixel wins, which is what makes the
    // overlapping rims visible.
    static float4 foldShutter(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                              sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float h = 1.0f-uv.y;
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        uint n = clamp(u.segments,2u,8u);
        float panel = 1.0f/float(n);
        // Depth cues were tuned for four panels: express each panel's rank as a
        // fraction of that stack so eight panels do not shade to black. Exactly
        // 1.0 at four panels, so the default output stays bit-identical.
        float perPanel = 4.0f/float(n);
        // Intensity scales how far every panel drops. 0.5 multiplies by an exact 1.0.
        float k = (u.intensity == 0.5f) ? 1.0f : exp2((clamp(u.intensity,0.0f,1.0f)-0.5f)*2.0f*log2(1.6f));
        float sink = panel+0.12f*persp;
        float relief = shad*smoothstep(0.0f,0.10f,p);
        float feather = 0.0016f+0.004f*soft;
        float3 color = float3(0.0f);
        float covered = 0.0f;
        for (uint j=0;j<n;j++) {
            float rank = float(j)*perPanel;
            float drop = k*p*(panel*float(j)+sink);
            float row = h+drop;
            float low = panel*float(j);
            float inset = persp*0.022f*rank*p/aspect;
            float cover = smoothstep(0.0f,feather,low+panel-row)*smoothstep(0.0f,feather,row-low)
                        * smoothstep(0.0f,feather,uv.x-inset)*smoothstep(0.0f,feather,1.0f-inset-uv.x);
            cover *= 1.0f-covered;
            if (cover <= 0.0f) continue;
            float sigmaUV = soft*0.014f*rank*(u.defocus >= 0 ? u.defocus : p);
            float3 slab = foldSample(desktop,pyramid,s,float2(uv.x,1.0f-row),sigmaUV);
            // The bevel on this panel's own top edge, then the shadow the panel
            // in front of it drops across this one.
            float rim = 1.0f+relief*0.35f*exp(-(low+panel-row)/(0.004f+0.008f*soft));
            float shade = 1.0f-relief*0.09f*rank*p;
            if (j > 0u) {
                float frontTop = panel*float(j)-k*p*(panel*float(j-1u)+sink);
                shade *= 1.0f-relief*0.55f*exp(-max(0.0f,h-frontTop)/(0.012f+0.03f*soft));
            }
            color += min(slab*rim*shade,float3(1.0f))*cover;
            covered += cover;
        }
        return float4(color*(1.0f-smoothstep(0.90f,1.0f,p)),1);
    }
    """#
}
