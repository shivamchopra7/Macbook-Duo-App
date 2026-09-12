import Foundation

/// Ripple: liquid rings spread from the hinge and the desktop drains into it.
enum ShaderRipple {
    static let function = #"""
    // ---------------------------------------------------------------- Ripple
    // Liquid. The hinge centre is a sink: per pixel the aspect-corrected radius r
    // gives one radial inverse map. Rings A*sin(k*r-phase) travel outward behind
    // an expanding front and fade with distance; a drain pull, strongest at the
    // sink's rim, makes the picture slide down into a hole that widens from the
    // hinge, so the far corners are the last to go. Crests carry a caustic and
    // troughs sink into shadow; defocus follows the wave and the drain speed.
    static float4 foldRipple(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                             sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float gain = 0.4f+1.2f*clamp(u.intensity,0.0f,1.0f);
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        float h = 1.0f-uv.y;
        float2 q = float2((uv.x-0.5f)*aspect,h);
        float r = length(q);
        float2 dir = q/max(r,1e-5f);

        // The sink widens from the hinge; content accelerates as it nears the rim.
        float hole = 1.15f*p*p*(0.6f+0.4f*p);
        float ahead = max(r-hole,0.0f);
        float pull = gain*p*p*(0.12f+0.28f*exp(-ahead/0.30f));
        // Rings only exist behind an expanding front, and lose height far out.
        float front = 0.25f+1.5f*p;
        float envelope = (1.0f-smoothstep(front-0.30f,front,r))*exp(-r/(0.55f+0.45f*p));
        float k = 2.0f*M_PI_F*(5.5f+2.0f*persp);
        float theta = k*r-2.0f*M_PI_F*3.2f*p;
        float wave = sin(theta), slope = cos(theta);
        float amplitude = 0.018f*gain*p*envelope;
        float ripple = amplitude*wave;

        // Inverse map: what shows at r came from farther out along the same ray.
        float rs = r+pull+ripple;
        float2 src = float2(0.5f+dir.x*rs/aspect,1.0f-dir.y*rs);
        float focus = u.defocus >= 0 ? u.defocus : p;
        // A faint whole-surface haze under the wave and drain terms: liquid is
        // never pin-sharp, and it keeps the reads on coarser pyramid levels.
        float sigmaUV = soft*focus*(0.003f+0.45f*abs(ripple)+0.35f*amplitude*abs(slope)+0.03f*pull);

        // Drained regions: past the source's top or sides, or inside the sink.
        // Those pixels are black whatever the source holds, so skip the fetch.
        float feather = p*(0.012f+0.025f*soft)+0.5f*sigmaUV;
        float mask = smoothstep(0.0f,feather,src.y)
                   * smoothstep(0.0f,feather/aspect,src.x)*smoothstep(0.0f,feather/aspect,1.0f-src.x);
        float aa = p*(0.02f+0.03f*soft)+0.5f*sigmaUV;
        mask *= smoothstep(0.0f,aa,r-hole);
        if (mask <= 0.0f) return float4(0,0,0,1);
        float3 color = foldSample(desktop,pyramid,s,src,sigmaUV);

        // Optics: a caustic on each crest, a lit flank, and shadowed troughs.
        float relief = shad*smoothstep(0.0f,0.10f,p);
        float strength = clamp(amplitude/0.009f,0.0f,1.0f);
        float lift = max(wave,0.0f)*max(wave,0.0f);
        float crest = lift*lift*lift;
        color *= 1.0f+relief*strength*(0.48f*crest+0.14f*slope-0.26f*max(-wave,0.0f));
        // The water's edge: a thin glint on the rim, then a fall into the sink.
        float edge = 0.04f+0.05f*soft;
        color *= 1.0f-relief*0.55f*exp(-ahead/edge);
        float glint = smoothstep(0.0f,0.5f*edge,ahead)*(1.0f-smoothstep(0.5f*edge,edge,ahead));
        color += relief*0.22f*glint*smoothstep(0.0f,0.15f,hole);
        return float4(min(color,float3(1.0f))*mask*(1.0f-smoothstep(0.88f,1.0f,p)),1);
    }
    """#
}
