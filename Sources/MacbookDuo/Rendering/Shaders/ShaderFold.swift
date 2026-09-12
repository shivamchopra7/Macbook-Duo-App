import Foundation

/// Metal source for the Fold effect. Placeholder: falls through to Duo until implemented.
enum ShaderFold {
    static let function = #"""
    // ---------------------------------------------------------------- Fold
    static float4 foldFold(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        return foldDuo(uv,desktop,pyramid,s,u,p);
    }
    """#
}
