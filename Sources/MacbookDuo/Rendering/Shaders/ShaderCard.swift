import Foundation

/// Card: the whole desktop is one rigid card hinged at the bottom, tipping back
/// away from a fixed viewer in true perspective.
enum ShaderCard {
    static let function = #"""
    // ---------------------------------------------------------------- Card
    // One rigid card hinged along the bottom edge tips back from a viewer fixed
    // in front of the resting plane. Each output pixel casts the viewer's ray
    // through the resting screen and intersects the tilted card; the hit point is
    // the source uv, so the top recedes into a foreshortened trapezoid and rays
    // that miss the card stay dark. Lambert shading, a sheen that sweeps down
    // the card and defocus growing with tilt and hinge distance finish the lid.
    static float4 foldCard(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        const float maxAngle = 85.0f*M_PI_F/180.0f;
        // Intensity bends the tilt response around the nominal: lazy at 0, eager at 1.
        float bias = 2.0f*clamp(u.intensity,0.0f,1.0f)-1.0f;
        float k = bias >= 0.0f ? 2.5f*bias : 0.75f*bias;
        float x = clamp((u.tilt >= 0.0f ? u.tilt : p*maxAngle)/maxAngle,0.0f,1.0f);
        float angle = maxAngle*x*(1.0f+k)/(1.0f+k*x);
        float sn = sin(angle), cs = cos(angle);

        // Viewer at (0,eyeY,D) in height units, in front of the resting plane z=0.
        // The card's normal is (0,sn,cs); t is the ray parameter to the card.
        const float eyeY = 0.55f;
        float D = mix(2.6f,1.3f,persp);
        float sy = 1.0f-uv.y;
        float num = eyeY*sn+D*cs;
        float t = num/max(num-sy*sn,1e-4f);
        float h = (eyeY+t*(sy-eyeY))*cs-D*(1.0f-t)*sn;
        float2 sourceUV = float2(0.5f+(uv.x-0.5f)*t,1.0f-h);
        // Ease the first 1.7 degrees without a pixel jump from exact passthrough.
        float onset = clamp(angle/0.03f,0.0f,1.0f);
        onset = onset*onset*onset*(onset*(onset*6.0f-15.0f)+10.0f);
        sourceUV = mix(uv,sourceUV,onset);
        float hinge = clamp(1.0f-sourceUV.y,0.0f,1.0f);

        // Defocus grows with the tilt and with distance from the hinge; the
        // foreshortened top is also minified, which sets a floor on the filter.
        float focus = u.defocus >= 0 ? pow(clamp(u.defocus,0.0f,1.0f),1.25f) : p;
        float sigmaUV = soft*0.05f*focus*(0.10f+0.90f*pow(hinge,1.4f))*(0.35f+0.65f*sn);
        float2 footprint = fwidth(sourceUV)*float2(desktop.get_width(),desktop.get_height());
        sigmaUV = max(sigmaUV,0.5f*max(0.0f,max(footprint.x,footprint.y)-1.0f)/float(desktop.get_height()));
        float3 color = foldSample(desktop,pyramid,s,sourceUV,sigmaUV);

        // Lambert from a light just above the viewer, plus depth dimming toward
        // the far edge; a soft sheen band travels from the top edge to the hinge.
        float lambert = clamp(cs+0.10f*sn,0.0f,1.0f);
        float shade = mix(1.0f,lambert,0.9f*shad)*(1.0f-0.12f*shad*hinge*sn);
        float band = (hinge-(1.05f-1.25f*x))/0.16f;
        float sheen = (0.10f+0.16f*shad)*exp(-band*band)*smoothstep(0.0f,0.10f,angle);
        color = min(color*shade+sheen,float3(1.0f));

        // Feather the card's silhouette with the same softness as its content,
        // never narrower than one output pixel and never wide enough to leak.
        float2 feather = max(float2(2.5f*sigmaUV/aspect,2.5f*sigmaUV)+soft*0.0015f,fwidth(sourceUV));
        feather = min(feather,float2(0.06f));
        float2 border = smoothstep(-feather,feather,sourceUV)
                       *(1.0f-smoothstep(1.0f-feather,1.0f+feather,sourceUV));
        float edgeCoverage = mix(1.0f,border.x*border.y,smoothstep(0.0f,0.025f,angle));
        float disappear = 1.0f-smoothstep(0.88f,1.0f,p);
        return float4(color*edgeCoverage*disappear,1);
    }
    """#
}
