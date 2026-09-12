import Foundation

/// Metal source for the Louver effect. Placeholder: falls through to Duo until implemented.
enum ShaderLouver {
    static let function = #"""
    // ---------------------------------------------------------------- Louver
    static float4 foldLouver(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        return foldDuo(uv,desktop,pyramid,s,u,p);
    }
    """#
}
