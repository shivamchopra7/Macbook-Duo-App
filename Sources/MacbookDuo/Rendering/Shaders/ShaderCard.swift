import Foundation

/// Metal source for the Card effect. Placeholder: falls through to Duo until implemented.
enum ShaderCard {
    static let function = #"""
    // ---------------------------------------------------------------- Card
    static float4 foldCard(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        return foldDuo(uv,desktop,pyramid,s,u,p);
    }
    """#
}
