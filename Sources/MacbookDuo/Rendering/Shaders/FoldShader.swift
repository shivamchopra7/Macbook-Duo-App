import Foundation

enum FoldShader {
    /// One fragment pass. Every effect is a bounded analytic inverse map from the
    /// output pixel back into the desktop image, plus the shared blur pyramid for
    /// prefiltering and depth cues. `effect` mirrors `FoldEffect.shaderIndex`;
    /// an unrecognized index falls through to Duo exactly as Swift does.
    ///
    /// Assembled from per-effect fragments. Metal requires every function to be
    /// declared before use, so `ShaderCommon.header` comes first, the effects
    /// next, and `ShaderCommon.dispatch` last. Add a new effect as a new file.
    static let source = [
        ShaderCommon.header,
        ShaderDuo.function,
        ShaderGhost.function,
        ShaderRoll.function,
        ShaderShutter.function,
        ShaderFlex.function,
        ShaderIris.function,
        ShaderCommon.dispatch,
    ].joined(separator:"\n")
}
