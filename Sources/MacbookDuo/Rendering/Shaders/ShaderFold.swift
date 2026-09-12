import Foundation

/// Fold: a bi-fold crease across the middle; the top half folds down over the bottom.
enum ShaderFold {
    static let function = #"""
    // ---------------------------------------------------------------- Fold
    // A crease crosses the screen at height c. The bottom half stays put; the
    // top half is a rigid flap of length L hinged at the crease that rotates
    // toward the viewer and down by theta. Every screen row is a ray from an eye
    // above the display (height ey, distance D), so the inverse is a single
    // projective divide t = D(h-c)/((h-ey)sin+D cos): the distance along the flap,
    // with x narrowing by (D-z)/D. The flap draws over the bottom half, throws a
    // cast shadow ahead of its tip and a contact shadow at the crease.
    static float4 foldFold(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float intensity = clamp(u.intensity,0.0f,1.0f);
        float h = 1.0f-uv.y;
        float c = mix(0.58f,0.42f,intensity);
        float L = 1.0f-c;
        float theta = M_PI_F*pow(p,mix(1.4f,0.85f,intensity));
        float sn = max(sin(theta),0.0f), cs = cos(theta);
        float fold = 0.5f*(1.0f-cs);
        float D = mix(3.2f,1.5f,persp);
        const float ey = 1.12f;
        float defocus = u.defocus >= 0 ? u.defocus : p;

        // Bottom half: the exact desktop, under the shadows the flap throws on it.
        float3 color = float3(0.0f);
        float creaseDepth = shad*sqrt(fold);
        if (h < c) {
            float3 bottom = desktop.sample(s,uv).rgb;
            float creaseAO = creaseDepth*(0.30f*exp(-(c-h)/(0.02f+0.06f*fold+0.02f*soft))
                                        + 0.25f*exp(-(c-h)/0.004f));
            // The tip's shadow under a light from the front and above (slope 2),
            // with a penumbra that widens with the tip's height off the surface.
            float shadowEdge = c+L*cs-L*sn*0.5f;
            float penumbra = 0.006f+0.10f*sn+0.02f*soft;
            float cast = shad*0.5f*smoothstep(-penumbra,penumbra,h-shadowEdge);
            color = bottom*(1.0f-creaseAO)*(1.0f-cast);
        }

        // Flap: the row's projective inverse, then the trapezoid in x.
        float denom = (h-ey)*sn+D*cs;
        denom = abs(denom) < 1e-5f ? 1e-5f : denom;
        float t = D*(h-c)/denom;
        float ratio = abs(D*((c-ey)*sn+D*cs))/(denom*denom);
        float feather = min(0.0025f*max(ratio,1.0f),0.02f);
        float cover = smoothstep(-feather,0.0f,t)*smoothstep(0.0f,feather,L-t);
        if (cover > 0.0f) {
            float z = t*sn;
            float scale = (D-z)/D;
            float2 src = float2(0.5f+(uv.x-0.5f)*scale,1.0f-(c+t));
            float compress = 1.0f-1.0f/max(ratio,1.0f);
            float sigmaUV = min(0.5f*max(ratio-1.0f,0.0f)/float(desktop.get_height()),0.03f)
                          + soft*0.030f*defocus*(0.10f*fold+0.90f*compress);
            float3 flap = foldSample(desktop,pyramid,s,src,sigmaUV);
            // Two-sided diffuse under a light from the front and above, measured
            // against the resting pose so the open image is untouched; the crease
            // itself sits in the same ambient shadow on the flap side.
            float2 n = float2(-sn,cs);
            const float2 light = normalize(float2(0.35f,1.0f));
            float dark = (light.y-dot(n,light))/(light.y+1.0f);
            float shade = 1.0f-shad*0.7f*dark;
            shade *= 1.0f-creaseDepth*(0.22f*exp(-max(t,0.0f)/(0.02f+0.03f*fold))
                                      + 0.25f*exp(-abs(t)/0.004f));
            // The lid's edge catches the light as it turns.
            float rim = (0.10f+0.25f*shad)*sn*exp(-max(L-t,0.0f)/(0.006f+0.004f*soft));
            // Gloss: a band travelling from the tip to the crease as the panel
            // turns, plus a sheen where the surface is seen at a grazing angle.
            float2 view = normalize(float2(ey-(c+t*cs),D-z));
            float facing = abs(dot(n,view));
            float bandAt = L*(0.9f-0.8f*theta/M_PI_F);
            float bandWidth = L*(0.10f+0.08f*soft);
            float band = exp(-pow((t-bandAt)/bandWidth,2.0f));
            float gloss = (0.08f+0.24f*shad)*pow(sn,1.2f)*band
                        + (0.05f+0.12f*shad)*pow(1.0f-facing,4.0f)+rim;
            color = mix(color,min(flap*shade+gloss,float3(1.0f)),cover);
        }
        return float4(color*(1.0f-smoothstep(0.88f,1.0f,p)),1);
    }
    """#
}
