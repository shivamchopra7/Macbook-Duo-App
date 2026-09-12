import Foundation
import Testing
@testable import FoldCore

@Test func defaultsMatchTheOriginalTuning() {
    let options = EffectOptions.default
    #expect(options.intensity == 0.5)
    #expect(options.segments == 4)
    #expect(options.curve == .smooth)
    #expect(options.responseTime == 0.045)
    #expect(options.clearDuration == 0.6)
    #expect(EffectOptions() == options)
}

@Test func everyFieldIsClampedAndNonFiniteInputFallsBack() {
    let wild = EffectOptions(intensity: 7, segments: 99, curve: .linear, responseTime: -3, clearDuration: .infinity)
    #expect(wild.intensity == 1)
    #expect(wild.segments == EffectOptions.segmentRange.upperBound)
    #expect(wild.responseTime == EffectOptions.responseRange.lowerBound)
    #expect(wild.clearDuration == EffectOptions.default.clearDuration)
    let nan = EffectOptions(intensity: .nan, segments: -1, curve: .smooth, responseTime: .nan, clearDuration: -1)
    #expect(nan.intensity == EffectOptions.default.intensity)
    #expect(nan.segments == EffectOptions.segmentRange.lowerBound)
    #expect(nan.responseTime == EffectOptions.default.responseTime)
    #expect(nan.clearDuration == EffectOptions.clearRange.lowerBound)
}

@Test func persistedCurveResolvesLikeEffects() {
    #expect(FoldCurve.resolve(persisted: nil) == .smooth)
    #expect(FoldCurve.resolve(persisted: "bounce") == .smooth)
    for curve in FoldCurve.allCases {
        #expect(FoldCurve.resolve(persisted: curve.rawValue) == curve)
        #expect(curve.id == curve.rawValue)
        #expect(!curve.title.isEmpty)
        #expect(!curve.symbol.isEmpty)
    }
    #expect(Set(FoldCurve.allCases.map(\.title)).count == FoldCurve.allCases.count)
}

@Test func curvesAreMonotonicAndPinnedAtBothEnds() {
    for curve in FoldCurve.allCases {
        #expect(curve.apply(0) == 0)
        #expect(curve.apply(1) == 1)
        #expect(curve.apply(-4) == 0)
        #expect(curve.apply(9) == 1)
        #expect(curve.apply(.nan) == 0)
        var previous = 0.0
        for step in 1...200 {
            let value = curve.apply(Double(step)/200)
            #expect(value >= previous - 1e-12, "\(curve) must not reverse")
            #expect(value >= 0 && value <= 1)
            previous = value
        }
    }
    #expect(FoldCurve.smooth.apply(0.5) == 0.5)
    #expect(FoldCurve.linear.apply(0.25) == 0.25)
    #expect(FoldCurve.brisk.apply(0.25) > 0.25)   // fast start
    #expect(FoldCurve.gentle.apply(0.25) < 0.25)  // slow start
}

@Test func shaderIntensityAndSegmentsAreExactlyRepresentable() {
    let options = EffectOptions(intensity: 0.25, segments: 6, curve: .brisk, responseTime: 0.08, clearDuration: 1)
    #expect(options.shaderIntensity == 0.25)
    #expect(options.shaderSegments == 6)
    #expect(EffectOptions.segmentRange == 2...8)
}
