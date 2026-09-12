import Foundation

/// Roll: the sheet wraps onto a growing cylinder from the top down.
enum ShaderRoll {
    static let function = #"""
    // ---------------------------------------------------------------- Roll
    // The sheet stays flat from the hinge up to a tangent height that descends
    // with the angle. Above it the material wraps a cylinder whose radius grows
    // like a spiral roll, so arc length is the inverse map: one asin per pixel.
    static float4 foldRoll(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float h = 1.0f-uv.y;
        // Intensity scales the material thickness, and with it how fast the
        // roll's radius grows. 0.5 multiplies by an exact 1.0, and the bound
        // keeps the scaled value an opaque operand of the radius expression, so
        // the default output stays bit-identical under fast-math reassociation.
        float k = (u.intensity == 0.5f) ? 1.0f : exp2((clamp(u.intensity,0.0f,1.0f)-0.5f)*2.0f*log2(1.6f));
        float thickness = clamp(k*(0.028f+0.055f*persp),0.0f,0.25f);
        float tangent = 1.0f-p;
        float radius = sqrt(0.0001f+thickness*p/M_PI_F);
        float feather = 0.0022f+0.004f*soft;

        // The lowest material on the roll: the loose edge stops before the
        // underside once the whole image has been taken up.
        float edgeAngle = clamp((1.0f-tangent)/max(radius,1e-5f),M_PI_F*0.5f,M_PI_F*1.5f);
        float lowest = min(tangent,tangent+radius*sin(edgeAngle));

        float3 plane = desktop.sample(s,uv).rgb;
        plane *= 1.0f-shad*0.5f*exp(-max(0.0f,lowest-h)/(0.05f+0.05f*soft));
        float3 color = plane*smoothstep(0.0f,feather,tangent-h);

        float wrap = clamp((h-tangent)/max(radius,1e-5f),-1.0f,1.0f);
        float theta = M_PI_F-asin(wrap);
        float arc = tangent+radius*theta;
        float facing = max(abs(cos(theta)),0.015f);
        float sigmaUV = min(0.45f/(facing*float(desktop.get_height())),0.03f)
                      + soft*0.030f*(u.defocus >= 0 ? u.defocus : p)*(0.25f+0.75f*(1.0f-facing));
        float3 rolled = foldSample(desktop,pyramid,s,float2(uv.x,1.0f-arc),sigmaUV);
        float lambert = max(0.0f,0.548f*sin(theta)-0.836f*cos(theta));
        float gloss = pow(lambert,14.0f);
        rolled *= mix(1.0f,0.42f+0.58f*lambert,0.35f+0.65f*shad)+gloss*(0.08f+0.20f*shad);
        float onRoll = smoothstep(0.0f,feather,radius-abs(h-tangent))
                     * smoothstep(0.0f,feather*2.0f+0.5f*sigmaUV,1.0f-arc);
        color = mix(color,rolled,onRoll);
        return float4(min(color,float3(1.0f))*(1.0f-smoothstep(0.88f,1.0f,p)),1);
    }
    """#
}
