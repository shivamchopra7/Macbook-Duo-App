import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Every effect: exact open, exact reopen, opaque black at closure, the shared
    /// Reduce Motion fade, a distinctive intermediate frame, deterministic reversal
    /// and reuse of a cached pyramid. Generated fixtures only.
    static func checkEffects(_ device: MTLDevice, _ renderer: FoldRenderer,
                             _ art: MTLTexture, _ output: URL) throws -> [String: Any] {
        let W = 960, H = 624
        let plate = try target(device,W,H)
        let artPlate = try target(device,art.width,art.height)
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var checkerBytes = [UInt8](repeating:0,count:W*H*4)
        checker.getBytes(&checkerBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)

        var report: [String: Any] = [:]
        var middles: [FoldEffect: Frame] = [:]
        for effect in FoldEffect.allCases {
            var u = FoldUniforms(); u.effect = effect.shaderIndex
            let open = try render(renderer,checker,plate,u)
            try require(open.pixels == checkerBytes,"\(effect.title): the open desktop is not an exact passthrough.")
            if effect != .duo {
                // Opening/clearing must not abruptly remove a shadow or seam at
                // the exact-zero branch. A tiny angle change stays visually tiny.
                u.progress = 0.001
                let onset = try render(renderer,checker,plate,u)
                let maximumJump = zip(onset.pixels,checkerBytes).map { abs(Int($0)-Int($1)) }.max() ?? 0
                try require(maximumJump <= 1,"\(effect.title): near-open transition jumps by \(maximumJump) channel levels.")
                report["\(effect.rawValue)NearOpenMaximumChannelJump"] = maximumJump
            }
            u.progress = 1
            let closed = try render(renderer,checker,plate,u)
            try require(stride(from:0,to:closed.pixels.count,by:4).allSatisfy {
                closed.pixels[$0] == 0 && closed.pixels[$0+1] == 0 && closed.pixels[$0+2] == 0
            },"\(effect.title): the closed lid did not black out.")
            u.progress = 0
            let reopened = try render(renderer,checker,plate,u)
            try require(reopened.pixels == checkerBytes,"\(effect.title): reopening changed the desktop.")
            u.progress = 0.5; u.fadeOnly = 1
            let reduced = try render(renderer,checker,plate,u)
            let halved = checkerBytes.enumerated().map { $0.offset%4 == 3 ? UInt8(255) : UInt8((Double($0.element)*0.5).rounded()) }
            try require(zip(reduced.pixels,halved).allSatisfy { abs(Int($0)-Int($1)) <= 1 },
                "\(effect.title): Reduce Motion did not take the shared fade.")
            u.fadeOnly = 0

            // Ascending then descending through the same angles must repeat exactly,
            // including when the descent reuses a cached blur pyramid.
            var ascending: [[UInt8]] = []
            let steps: [Float] = [0.1,0.25,0.4,0.55,0.7,0.85]
            for step in steps { u.progress = step; ascending.append(try render(renderer,checker,plate,u).pixels) }
            for (index,step) in steps.enumerated().reversed() {
                u.progress = step
                let descending = try render(renderer,checker,plate,u,revision:4000)
                try require(descending.pixels == ascending[index],
                    "\(effect.title): closing and opening did not reverse identically.")
            }
            let builds = renderer.blurBuildCount
            u.progress = 0.5
            let cached = try render(renderer,checker,plate,u,revision:4100)
            let reused = try render(renderer,checker,plate,u,revision:4100)
            try require(reused.pixels == cached.pixels,
                "\(effect.title): a cached pyramid changed the rendered pixels.")
            try require(renderer.blurBuildCount == builds+1,"\(effect.title): an unchanged frame rebuilt its blur pyramid.")

            var a = FoldUniforms(); a.effect = effect.shaderIndex
            for step in [0,25,50,75,100] {
                a.progress = Float(step)/100
                let frame = try render(renderer,art,artPlate,a)
                try save(frame,output.appendingPathComponent("effect-\(effect.rawValue)-\(step).png"))
                if step == 50 { middles[effect] = frame }
            }
            report["\(effect.rawValue)ExactOpenReopenClosedAndReduceMotion"] = true
        }

        // Each effect must look like itself, not like a relabelled neighbour.
        var separation: [String: Double] = [:]
        var worst = 255.0
        for (i,left) in FoldEffect.allCases.enumerated() {
            for right in FoldEffect.allCases.dropFirst(i+1) {
                let difference = meanAbsDiff(middles[left]!,middles[right]!)
                separation["\(left.rawValue)-\(right.rawValue)"] = difference
                worst = min(worst,difference)
            }
        }
        try require(worst >= 6,"Two effects render nearly the same intermediate frame.")
        report["intermediateSeparationMeanChannelDifference"] = separation
        report["smallestIntermediateSeparation"] = worst
        // A newly learned resting angle can be near closure. Small movements
        // there must still leave a usable image, for every shader style.
        let lowAngleSource = try fixture(device,width:W,height:H) { _,_ in 200 }
        var lowAngleChecks: [[String:Any]] = []
        for effect in FoldEffect.allCases {
            for reference: Double in [5,10,20,30] {
                for delta: Double in [1,2,3] {
                    let state = FoldVisualState.at(angle:reference-delta,reference:reference)
                    var u = FoldUniforms(); u.effect = effect.shaderIndex
                    u.progress = Float(state.progress); u.defocus = Float(state.defocus)
                    u.tilt = Float(state.tilt); u.referenceAngle = Float(state.referenceAngle)
                    let frame = try render(renderer,lowAngleSource,plate,u)
                    let mean = Double(stride(from:0,to:frame.pixels.count,by:4).reduce(0) { $0+Int(frame.pixels[$1]) })/Double(W*H)
                    try require(mean > 150,"\(effect.title): a tiny movement from a low resting angle hid too much of the display.")
                    lowAngleChecks.append(["effect":effect.persistedIdentifier,"reference":reference,"delta":delta,"meanChannel":mean])
                }
            }
        }
        report["lowRestingAngleChecks"] = lowAngleChecks
        try report.merge(checkGhost(device,renderer,plate,W,H)) { a,_ in a }
        try report.merge(checkRoll(device,renderer,plate,W,H)) { a,_ in a }
        try report.merge(checkShutter(device,renderer,plate,W,H)) { a,_ in a }
        try report.merge(checkFlex(device,renderer,plate,W,H)) { a,_ in a }
        try report.merge(checkIris(device,renderer,plate,W,H)) { a,_ in a }
        return report
    }

    /// Native-resolution cost for every effect, worst case: a new source frame
    /// rebuilds the pyramid on each render. GPU-only timings.
    static func benchmarkEffects(_ device: MTLDevice, _ renderer: FoldRenderer,
                                 _ source: MTLTexture, _ destination: MTLTexture) throws -> [String: Any] {
        var results: [String: Any] = [:]
        for effect in FoldEffect.allCases {
            var times: [Double] = []
            for i in 0..<60 {
                var u = FoldUniforms(); u.effect = effect.shaderIndex
                u.progress = 0.04+Float(i%24)/25
                let command = try encode(renderer,source,destination,u)
                command.waitUntilCompleted()
                try require(command.status == .completed,"\(effect.title): native render failed.")
                if i >= 10 { times.append((command.gpuEndTime-command.gpuStartTime)*1000) }
            }
            times.sort()
            let p95 = times[Int(Double(times.count)*0.95)]
            try require(p95 < 6,"\(effect.title): native GPU p95 exceeded the 6 ms rendering budget.")
            results[effect.rawValue] = ["medianMS":times[times.count/2],"p95MS":p95]
        }
        return results
    }
}
