import Foundation

/// Metal source for the Ripple effect. Placeholder: falls through to Duo until implemented.
enum ShaderRipple {
    static let function = #"""
    // ---------------------------------------------------------------- Ripple
    static float4 foldRipple(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        return foldDuo(uv,desktop,pyramid,s,u,p);
    }
    """#
}
