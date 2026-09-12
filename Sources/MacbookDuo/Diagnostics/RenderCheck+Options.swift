import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// The six original effects honour `intensity` and `segments` without
    /// changing their default output: intensity 0.5 is bit-identical to the
    /// original tuning, the extremes are visibly distinct, intensity 1 keeps the
    /// near-open, closed and low-resting-angle contracts, and only Shutter
    /// responds to the segment count. Generated fixtures only.
    static let optionEffects: [FoldEffect] = [.duo, .ghost, .roll, .shutter, .flex, .iris]

    static func checkOptions(_ device: MTLDevice, _ renderer: FoldRenderer,
                             _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var checkerBytes = [UInt8](repeating:0,count:W*H*4)
        checker.getBytes(&checkerBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        let gray = try fixture(device,width:W,height:H) { _,_ in 200 }
        var report: [String: Any] = [:]
        for effect in optionEffects where checkedEffects.contains(effect) {
            var u = FoldUniforms(); u.effect = effect.shaderIndex; u.progress = 0.5
            let plain = try render(renderer,checker,plate,u)
            var result = try intensityContrast(renderer,checker,plate,effect,plain)
            try result.merge(intensityContracts(renderer,checker,plate,checkerBytes,effect)) { a,_ in a }
            try result.merge(lowRestingAngleAtFullIntensity(renderer,gray,plate,effect,W*H)) { a,_ in a }
            try result.merge(segmentSensitivity(renderer,checker,plate,effect,plain)) { a,_ in a }
            report["\(effect.rawValue)Options"] = result
        }
        try saveOptionPreviews(renderer,plate)
        return report
    }

    /// Checker art at the intensity extremes and, for Shutter, at two and eight
    /// panels, next to the default frames the effect loop already writes.
    private static func saveOptionPreviews(_ renderer: FoldRenderer, _ plate: MTLTexture) throws {
        let output = try outputDirectory.get()
        let art = try renderer.makePreviewTexture(width:plate.width,height:plate.height)
        for effect in optionEffects where checkedEffects.contains(effect) {
            for step in [25,50,75] {
                for intensity: Float in [0,1] {
                    var u = FoldUniforms(); u.effect = effect.shaderIndex
                    u.progress = Float(step)/100; u.intensity = intensity
                    try save(try render(renderer,art,plate,u),
                             output.appendingPathComponent("options-\(effect.rawValue)-intensity\(Int(intensity))-\(step).png"))
                }
                guard effect == .shutter else { continue }
                for segments: UInt32 in [2,8] {
                    var u = FoldUniforms(); u.effect = effect.shaderIndex
                    u.progress = Float(step)/100; u.segments = segments
                    try save(try render(renderer,art,plate,u),
                             output.appendingPathComponent("options-\(effect.rawValue)-segments\(segments)-\(step).png"))
                }
            }
        }
    }

    /// (a) intensity 0.5 reproduces the default frame exactly; (b) intensity 0
    /// and 1 each move away from it, and away from each other.
    private static func intensityContrast(_ renderer: FoldRenderer, _ checker: MTLTexture, _ plate: MTLTexture,
                                          _ effect: FoldEffect, _ plain: Frame) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = effect.shaderIndex; u.progress = 0.5
        u.intensity = 0.5
        let half = try render(renderer,checker,plate,u)
        try require(half.pixels == plain.pixels,"\(effect.title): intensity 0.5 changed the original tuning.")
        u.intensity = 0
        let low = try render(renderer,checker,plate,u)
        u.intensity = 1
        let high = try render(renderer,checker,plate,u)
        let lowDifference = meanAbsDiff(low,plain), highDifference = meanAbsDiff(high,plain)
        let span = meanAbsDiff(low,high)
        try require(lowDifference >= 2,"\(effect.title): intensity 0 is not visibly gentler than the default.")
        try require(highDifference >= 2,"\(effect.title): intensity 1 is not visibly stronger than the default.")
        try require(span >= 4,"\(effect.title): intensity 0 and 1 render nearly the same frame.")
        return ["intensityHalfBitIdentical":true,
                "intensityZeroMeanDifferenceFromDefault":lowDifference,
                "intensityOneMeanDifferenceFromDefault":highDifference,
                "intensityZeroToOneMeanDifference":span]
    }

    /// (c) At intensity 1 a tiny angle change still stays visually tiny and the
    /// closed lid still blacks out. Duo's zoom resamples the checker from the first
    /// pixel of movement, so the effect loop reports its jump without gating it.
    private static func intensityContracts(_ renderer: FoldRenderer, _ checker: MTLTexture, _ plate: MTLTexture,
                                           _ source: [UInt8], _ effect: FoldEffect) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = effect.shaderIndex; u.intensity = 1
        u.progress = 0.001
        let onset = try render(renderer,checker,plate,u)
        let jump = zip(onset.pixels,source).map { abs(Int($0)-Int($1)) }.max() ?? 0
        if effect != .duo {
            try require(jump <= 1,"\(effect.title): at intensity 1 the near-open transition jumps by \(jump) channel levels.")
        }
        u.progress = 1
        let closed = try render(renderer,checker,plate,u)
        try require(stride(from:0,to:closed.pixels.count,by:4).allSatisfy {
            closed.pixels[$0] == 0 && closed.pixels[$0+1] == 0 && closed.pixels[$0+2] == 0
        },"\(effect.title): at intensity 1 the closed lid did not black out.")
        return ["intensityOneNearOpenMaximumChannelJump":jump,"intensityOneClosedBlack":true]
    }

    /// (d) A small movement from a low resting angle keeps most of the display
    /// bright at intensity 1, as it must at the default.
    private static func lowRestingAngleAtFullIntensity(_ renderer: FoldRenderer, _ gray: MTLTexture, _ plate: MTLTexture,
                                                       _ effect: FoldEffect, _ pixelCount: Int) throws -> [String: Any] {
        let reference = 10.0, delta = 2.0
        let state = FoldVisualState.at(angle:reference-delta,reference:reference)
        var u = FoldUniforms(); u.effect = effect.shaderIndex; u.intensity = 1
        u.progress = Float(state.progress); u.defocus = Float(state.defocus)
        u.tilt = Float(state.tilt); u.referenceAngle = Float(state.referenceAngle)
        let frame = try render(renderer,gray,plate,u)
        let mean = Double(stride(from:0,to:frame.pixels.count,by:4).reduce(0) { $0+Int(frame.pixels[$1]) })/Double(pixelCount)
        try require(mean > 150,"\(effect.title): at intensity 1 a tiny movement from a low resting angle hid too much of the display.")
        return ["intensityOneLowRestingAngleMeanChannel":mean,
                "intensityOneLowRestingAngle":["reference":reference,"delta":delta]]
    }

    /// (e) Shutter changes with the panel count; the other originals ignore it.
    private static func segmentSensitivity(_ renderer: FoldRenderer, _ checker: MTLTexture, _ plate: MTLTexture,
                                           _ effect: FoldEffect, _ plain: Frame) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = effect.shaderIndex; u.progress = 0.5
        u.segments = 2
        let two = try render(renderer,checker,plate,u)
        u.segments = 8
        let eight = try render(renderer,checker,plate,u)
        let difference = meanAbsDiff(two,eight)
        if effect == .shutter {
            try require(difference >= 4,"Shutter: two and eight panels render nearly the same frame.")
        } else {
            try require(two.pixels == plain.pixels && eight.pixels == plain.pixels,
                "\(effect.title): the segment count changed an effect that has no segments.")
        }
        return ["segmentsTwoVersusEightMeanDifference":difference,
                "segmentsAffectOutput":effect == .shutter]
    }
}
