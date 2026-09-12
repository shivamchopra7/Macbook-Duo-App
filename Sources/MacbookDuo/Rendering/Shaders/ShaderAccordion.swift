import Foundation

/// Metal source for the Accordion effect. Placeholder: falls through to Duo until implemented.
enum ShaderAccordion {
    static let function = #"""
    // ---------------------------------------------------------------- Accordion
    static float4 foldAccordion(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        return foldDuo(uv,desktop,pyramid,s,u,p);
    }
    """#
}
