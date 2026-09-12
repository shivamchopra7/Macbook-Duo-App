import Foundation

/// Iris: eight overlapping blades close on a centre above the hinge.
enum ShaderIris {
    static let function = #"""
    // ---------------------------------------------------------------- Iris
    // Eight blades, each a half plane with a curved leading edge, closing on a
    // centre just above the hinge. The aperture is the maximum of the eight edge
    // functions, so coverage has no gaps; blade order only decides the shading,
    // which is what draws the overlapping seams. The desktop itself stays put.
    static float4 foldIris(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        float2 q = float2((uv.x-0.5f)*aspect,(1.0f-uv.y)-0.14f);
        // Intensity steepens the closing exponent and the twist, so the aperture
        // still opens fully at p=0 and shuts at p=1 at every setting. 0.5
        // multiplies by an exact 1.0, keeping the default bit-identical.
        float k = (u.intensity == 0.5f) ? 1.0f : exp2((clamp(u.intensity,0.0f,1.0f)-0.5f)*2.0f*log2(1.6f));
        float aperture = 1.32f*pow(1.0f-p,1.3f*k);
        float curve = 0.30f*persp;
        float twist = k*p*(0.16f+0.22f*persp);
        const uint blades = 8u;
        float pitch = 2.0f*M_PI_F/float(blades);
        float overhang = aperture*tan(M_PI_F/float(blades))+0.10f;

        float outside = -1e9f;
        uint owner = 0u, strongest = 0u;
        bool claimed = false;
        float ownerEdge = 0.0f;
        for (uint i=0;i<blades;i++) {
            float phi = float(i)*pitch+twist;
            float along = q.x*cos(phi)+q.y*sin(phi);
            float across = q.y*cos(phi)-q.x*sin(phi);
            float edge = along-aperture-curve*across*across;
            if (edge > outside) { outside = edge; strongest = i; }
            if (!claimed && edge >= 0.0f && across >= -overhang) {
                claimed = true; owner = i; ownerEdge = edge;
            }
        }
        if (!claimed) { owner = strongest; ownerEdge = max(outside,0.0f); }

        float inside = max(0.0f,-outside);
        // Keep gaining optical depth after the first 15 degrees, rather than
        // reaching full rim blur while the rest of the screen is nearly sharp.
        float rimSigma = soft*0.030f*(u.defocus >= 0 ? u.defocus : 1.0f)*exp(-inside/(0.035f+0.05f*soft));
        float3 color = foldSample(desktop,pyramid,s,uv,rimSigma);
        color *= 1.0f-shad*0.55f*exp(-inside/(0.028f+0.055f*soft));

        float phiOwner = float(owner)*pitch+twist;
        float tone = 0.052f+0.040f*(0.5f+0.5f*cos(phiOwner+0.7f));
        float body = tone*(1.0f-0.35f*smoothstep(0.0f,0.5f,ownerEdge));
        float seam = 1.0f;
        if (owner > 0u) {
            float phiAbove = float(owner-1u)*pitch+twist;
            float alongAbove = q.x*cos(phiAbove)+q.y*sin(phiAbove);
            float acrossAbove = q.y*cos(phiAbove)-q.x*sin(phiAbove);
            float past = -(acrossAbove+overhang);
            if (alongAbove >= aperture && past > 0.0f) {
                seam = 1.0f-(0.25f+0.45f*shad)*exp(-past/(0.010f+0.03f*soft));
            }
        }
        float shine = 0.26f*exp(-ownerEdge/(0.0035f+0.012f*soft));
        float3 blade = (body*seam+shine)*(1.0f-smoothstep(0.88f,1.0f,p));
        float aa = 1.5f/max(u.size.y,1.0f)+soft*0.0035f;
        return float4(min(mix(color,blade,smoothstep(0.0f,aa,outside)),float3(1.0f)),1);
    }
    """#
}
