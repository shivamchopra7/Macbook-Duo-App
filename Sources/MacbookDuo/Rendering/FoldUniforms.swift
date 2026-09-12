import FoldCore

/// 48 bytes, mirrored field for field by `Uniforms` in `FoldShader.source`.
struct FoldUniforms: Equatable {
    var progress: Float = 0
    var perspective: Float = 0.7
    var blur: Float = 0.65
    var shadow: Float = 0.65
    var size = SIMD2<Float>(1, 1)
    var fadeOnly: Float = 0
    var effect: UInt32 = FoldEffect.fallback.shaderIndex
    // A negative value retains normalized-progress fixtures; app paths provide physical defocus.
    var defocus: Float = -1
    var coverage: Float = 1
    // Negative values keep normalized-progress fixtures convenient. App paths supply radians.
    var tilt: Float = -1
    var referenceAngle: Float = 105

    var selectedEffect: FoldEffect { FoldEffect.resolve(shaderIndex: effect) }
}
