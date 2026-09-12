import Foundation

/// Flex: one continuous sheet bows inward and tips back.
enum ShaderFlex {
    static let function = #"""
    // ---------------------------------------------------------------- Flex
    // One continuous sheet: a dome silhouette, vertical foreshortening toward the
    // tipped-back top edge, and a horizontal cylindrical unwrap (asin) for the
    // inward bow. Everything is one continuous deformation of the same image.
    static float4 foldFlex(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float h = 1.0f-uv.y;
        float lateral = (uv.x-0.5f)*2.0f;
        float collapse = 1.0f-0.85f*smoothstep(0.72f,1.0f,p);
        float top = (1.0f-0.40f*p)*collapse*(1.0f-p*0.10f*lateral*lateral);
        float eta = h/max(top,1e-4f);
        // Intensity scales the bend and the bow together. 0.5 multiplies by an
        // exact 1.0, so the default output stays bit-identical.
        float k = (u.intensity == 0.5f) ? 1.0f : exp2((clamp(u.intensity,0.0f,1.0f)-0.5f)*2.0f*log2(1.6f));
        float bend = k*p*(0.45f+1.15f*persp);
        float material = eta*(1.0f+bend*eta)/(1.0f+bend);
        float waist = 1.0f-p*(0.10f+0.15f*persp)*material*material;
        float across = lateral/max(waist,1e-3f);
        float arc = k*p*(0.32f+0.42f*persp);
        float sweep = sin(arc);
        float unwrap = arc > 1e-4f ? asin(clamp(across*sweep,-0.99999f,0.99999f))/arc : across;
        float2 src = float2(0.5f+0.5f*unwrap,1.0f-material);

        float lean = clamp((1.0f+bend)/(1.0f+2.0f*bend*eta),0.02f,1.0f);
        float toward = clamp(lean*cos(unwrap*arc),0.02f,1.0f);
        float sigmaUV = min(0.45f/(lean*float(desktop.get_height())),0.02f)
                      + soft*(u.defocus >= 0 ? u.defocus : p)*(0.012f+0.030f*(1.0f-toward)+0.014f*eta);
        float3 color = foldSample(desktop,pyramid,s,src,sigmaUV);
        color *= mix(1.0f,0.35f+0.65f*toward,0.30f+0.70f*shad);
        // A glossy reflection band placed by the surface normal, not by a timeline.
        float sheenWidth = 0.10f+0.35f*arc;
        float sheen = exp(-pow((unwrap*arc+0.75f*arc)/sheenWidth,2.0f))*(0.35f+0.65f*eta);
        color += sheen*(0.05f+0.13f*shad)*p;
        color *= 1.0f-shad*0.30f*smoothstep(0.0f,0.10f,p)*exp(-h/0.03f);

        float fade = 0.0022f+0.004f*soft+1.2f*sigmaUV;
        float mask = smoothstep(0.0f,fade,1.0f-abs(across))*smoothstep(0.0f,fade,top-h)
                   * smoothstep(0.0f,p*(0.012f+0.025f*soft)+0.5f*sigmaUV,h);
        return float4(min(color,float3(1.0f))*mask*(1.0f-smoothstep(0.90f,1.0f,p)),1);
    }
    """#
}
