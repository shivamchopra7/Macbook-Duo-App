import Foundation

/// Metal source for the Curtain effect. Placeholder: falls through to Duo until implemented.
enum ShaderCurtain {
    static let function = #"""
    // ---------------------------------------------------------------- Curtain
    static float4 foldCurtain(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        return foldDuo(uv,desktop,pyramid,s,u,p);
    }
    """#
}
