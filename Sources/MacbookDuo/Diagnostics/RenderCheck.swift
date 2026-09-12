import AppKit
import MetalKit
import CoreVideo
import FoldCore

/// Offscreen checks use generated pixels only. No ScreenCaptureKit access.
@MainActor enum RenderCheck {
    struct Frame {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let gpuMS: Double
        func gray(_ x: Int, _ y: Int) -> Int { Int(pixels[(y*width+x)*4]) }
    }

    /// `--effects duo,fold` limits the effect loops so one shader can be validated alone.
    static var checkedEffects: [FoldEffect] {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--effects"), index+1 < args.count else { return FoldEffect.allCases }
        let identifiers = args[index+1].split(separator: ",").map(String.init)
        let chosen = FoldEffect.allCases.filter { identifiers.contains($0.persistedIdentifier) }
        return chosen.isEmpty ? FoldEffect.allCases : chosen
    }

    /// Validated once; `--render-check <dir>` must name a new directory outside protected locations.
    static let outputDirectory: Result<URL, Error> = {
        let args = CommandLine.arguments
        let path = args.firstIndex(of: "--render-check").flatMap { $0+1 < args.count ? args[$0+1] : nil } ?? "render-check"
        return Result { try DiagnosticPaths.newDirectory(path) }
    }()

    static func run() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw AppError.message("No Metal device.") }
        let renderer = try FoldRenderer(device: device)
        let args = CommandLine.arguments
        let output = try outputDirectory.get()
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let input = try renderer.makePreviewTexture()
        let surface = try target(device, input.width, input.height)
        var checkpoints: [[String: Any]] = []
        var openPixels: [UInt8] = []
        for step in [0,25,50,75,100,0] {
            var u = FoldUniforms(); u.progress = Float(step)/100
            let frame = try render(renderer, input, surface, u)
            if step == 0 {
                if openPixels.isEmpty { openPixels = frame.pixels }
                else { try require(openPixels == frame.pixels, "Reopening changed the desktop.") }
            }
            if step == 100 {
                try require(stride(from: 0, to: frame.pixels.count, by: 4).allSatisfy {
                    frame.pixels[$0] == 0 && frame.pixels[$0+1] == 0 && frame.pixels[$0+2] == 0
                }, "Closed desktop did not disappear.")
            }
            try save(frame, output.appendingPathComponent("fold-\(step).png"))
            checkpoints.append(["progress": Double(step)/100, "gpuMilliseconds": frame.gpuMS])
        }

        // A small hinge glyph gives a measurable contract for the requested enlargement.
        let w = 960, h = 624
        let glyph = try fixture(device, width: w, height: h) { x,y in
            (x >= w*48/100 && x < w*52/100 && y >= h*88/100 && y < h*92/100) ? 0 : 255
        }
        let testTarget = try target(device,w,h)
        var sharp = FoldUniforms(); sharp.blur = 0; sharp.shadow = 0
        let original = try render(renderer,glyph,testTarget,sharp)
        var sourceBytes = [UInt8](repeating: 0, count: w*h*4)
        glyph.getBytes(&sourceBytes,bytesPerRow:w*4,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
        try require(original.pixels == sourceBytes, "Open output is not an exact pixel passthrough.")
        let initialBounds = try glyphBounds(original)
        var growth: [[String: Any]] = []
        for perspective: Float in [0,0.27165042,0.7,1] {
            var previous = initialBounds
            for p: Float in [0.25,0.5,0.75] {
                sharp.progress = p; sharp.perspective = perspective
                let frame = try render(renderer,glyph,testTarget,sharp), bounds = try glyphBounds(frame)
                try require(bounds.width >= previous.width && bounds.height >= previous.height && bounds.y <= previous.y,
                    "Content shrank or moved away from the hinge expansion.")
                if p == 0.75 {
                    try require(bounds.width > initialBounds.width && bounds.height > initialBounds.height, "Icons did not enlarge.")
                }
                previous = bounds
                growth.append(["progress":p,"perspective":perspective,"width":bounds.width,"height":bounds.height,"top":bounds.y])
            }
        }
        sharp.progress = 0.5; sharp.fadeOnly = 1
        let reduced = try render(renderer,glyph,testTarget,sharp)
        let expected = sourceBytes.enumerated().map { $0.offset%4 == 3 ? UInt8(255) : UInt8((Double($0.element)*0.5).rounded()) }
        try require(zip(reduced.pixels,expected).allSatisfy { abs(Int($0)-Int($1)) <= 1 }, "Reduce Motion changed geometry or did not fade.")

        let checker = try fixture(device,width:w,height:h) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var optics = FoldUniforms(); optics.progress = 0.6; optics.shadow = 0; optics.blur = 0
        let unblurred = try render(renderer,checker,testTarget,optics)
        optics.blur = 0.65
        let blurred = try render(renderer,checker,testTarget,optics)
        let topRows = (h/5)..<(h*2/5), hingeRows = (h*4/5)..<(h*9/10)
        let topRatio = variation(blurred,rows:topRows)/variation(unblurred,rows:topRows)
        let hingeRatio = variation(blurred,rows:hingeRows)/variation(unblurred,rows:hingeRows)
        try require(topRatio < 0.25 && hingeRatio < 0.8 && topRatio < hingeRatio,
            "Defocus must soften both the top and hinge, with the top softer.")
        try save(blurred,output.appendingPathComponent("blur-checker.png"))

        // The user's 90-degree example must already soften content, then return
        // identical pixels when the shared stationary target becomes zero.
        var ninety = FoldUniforms()
        ninety.progress = Float(FoldMath.progress(angle:90,clearAngle:105))
        ninety.perspective = 0.27165042; ninety.shadow = 0; ninety.blur = 0
        let ninetySharp = try render(renderer,checker,testTarget,ninety)
        ninety.blur = 0.65
        let ninetyBlurred = try render(renderer,checker,testTarget,ninety)
        let ninetyRatio = variation(ninetyBlurred,rows:topRows)/variation(ninetySharp,rows:topRows)
        try require(ninetyRatio < 0.9, "90-degree live effect did not visibly soften the top content.")
        ninety.progress = 0
        let ninetyClear = try render(renderer,checker,testTarget,ninety)
        checker.getBytes(&sourceBytes,bytesPerRow:w*4,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
        try require(ninetyClear.pixels == sourceBytes, "Stationary 90-degree output retained blur.")

        let white = try fixture(device,width:w,height:h) { _,_ in 255 }
        let edges = try render(renderer,white,testTarget,optics)
        try require(edgeRamp(edges,horizontal:true) >= w*3/100 && edgeRamp(edges,horizontal:false) >= h*4/100,
            "The side or top fade is too narrow.")
        for x in 0..<w { try require(edges.gray(x,0) <= 8 && edges.gray(x,h-1) <= 8, "Hard top/bottom edge.") }
        for y in 0..<h { try require(edges.gray(0,y) <= 8 && edges.gray(w-1,y) <= 8, "Hard side edge.") }
        try save(edges,output.appendingPathComponent("edge-coverage.png"))
        let largerWhite = try fixture(device,width:w*2,height:h*2) { _,_ in 255 }
        let largerTarget = try target(device,w*2,h*2)
        let largerEdges = try render(renderer,largerWhite,largerTarget,optics)
        try require(abs(edgeRamp(largerEdges,horizontal:true)-2*edgeRamp(edges,horizontal:true)) <= 2,
            "Side falloff changed with Retina resolution.")

        // Three outstanding command buffers share the pyramid. Each must retain
        // its own input's color and return the same image when an angle repeats.
        let black = try fixture(device,width:w,height:h) { _,_ in 0 }
        let batchTargets = try (0..<3).map { _ in try target(device,w,h) }
        var commands: [MTLCommandBuffer] = []
        for (i,texture) in [white,black,white].enumerated() {
            commands.append(try encode(renderer,texture,batchTargets[i],optics,revision:UInt64(i+1)))
        }
        let batch = try commands.enumerated().map { try read(batchTargets[$0.offset],$0.element) }
        try require(batch[0].pixels == batch[2].pixels && batch[1].gray(w/2,h/2) == 0 && batch[0].gray(w/2,h/2) == 255,
            "Blur levels retained another frame or changed after reversal.")

        let cacheReference = try render(renderer,checker,testTarget,optics)
        let builds = renderer.blurBuildCount
        let firstCached = try render(renderer,checker,testTarget,optics,revision:1000)
        let nextCached = try render(renderer,checker,testTarget,optics,revision:1000)
        try require(cacheReference.pixels == firstCached.pixels && firstCached.pixels == nextCached.pixels,
            "Cached blur changed the rendered pixels.")
        try require(renderer.blurBuildCount == builds+1, "An unchanged frame rebuilt its blur pyramid.")
        // A recycled buffer can retain its identity while its content changes.
        let pooled = try fixture(device,width:w,height:h) { _,_ in 255 }
        let beforeReuse = try render(renderer,pooled,testTarget,optics,revision:1001)
        var changedPixels = [UInt8](repeating:0,count:w*h*4)
        for i in stride(from:3,to:changedPixels.count,by:4) { changedPixels[i] = 255 }
        pooled.replace(region:MTLRegionMake2D(0,0,w,h),mipmapLevel:0,withBytes:changedPixels,bytesPerRow:w*4)
        let afterReuse = try render(renderer,pooled,testTarget,optics,revision:1002)
        try require(beforeReuse.gray(w/2,h/2) == 255 && afterReuse.gray(w/2,h/2) == 0,
            "Recycled source retained stale blur pixels.")

        try require(MemoryLayout<FoldUniforms>.stride == 64, "Swift and Metal uniform layout must match.")
        var gradualOnset: [[String:Any]] = []
        for reference: Double in [45,60,90,105,128,140] {
            for delta: Double in [0,1,2,3,5,10,15] {
                let state = FoldVisualState.at(angle:reference-delta,reference:reference)
                var u = FoldUniforms();u.progress = Float(state.progress);u.defocus = Float(state.defocus)
                u.shadow = 0;u.blur = 0
                let sharpFrame = try render(renderer,checker,testTarget,u)
                u.blur = 0.65
                let softFrame = try render(renderer,checker,testTarget,u)
                let ratio = variation(softFrame,rows:topRows)/variation(sharpFrame,rows:topRows)
                if delta <= 3 { try require(ratio > 0.95, "A tiny bend became too blurry.") }
                if delta == 15 { try require(ratio < 0.75, "Fifteen degrees must be visibly more defocused.") }
                gradualOnset.append(["referenceAngle":reference,"delta":delta,"defocus":state.defocus,"contrastRatio":ratio])
                if reference == 90 {
                    try save(try render(renderer,input,surface,u),output.appendingPathComponent("gradual-\(Int(delta))-degrees.png"))
                }
            }
        }
        var clearChecks: [[String:Any]] = []
        for effect in checkedEffects {
            var animation = FoldVisualAnimation()
            let target = FoldVisualState.at(angle:75,reference:90)
            for tick in 0...120 { _ = animation.sample(target:target,at:Double(tick)/120) }
            _ = animation.sample(target:.clear,at:1)
            var finalPixels: [UInt8] = []
            for time in [0.0,0.15,0.3,0.45,0.5,0.55,0.59,0.601] {
                let state = animation.sample(target:.clear,at:1+time)
                var u = FoldUniforms();u.effect = effect.shaderIndex
                u.progress = Float(state.progress);u.defocus = Float(state.defocus);u.coverage = Float(state.coverage);u.tilt = Float(state.tilt); u.referenceAngle = Float(state.referenceAngle)
                let frame = try render(renderer,input,surface,u)
                try require(stride(from:3,to:frame.pixels.count,by:4).allSatisfy { frame.pixels[$0] == 255 }, "Clear transition lost opacity.")
                if time == 0.59 {
                    let jump = zip(frame.pixels,openPixels).map { abs(Int($0)-Int($1)) }.max() ?? 0
                    try require(jump <= 5, "Final clear handoff retained a visible jump.")
                    clearChecks.append(["effect":effect.persistedIdentifier,"lastFrameMaxChannelDifference":jump])
                }
                if time == 0 || time == 0.3 || time == 0.55 || time == 0.601 {
                    try save(frame,output.appendingPathComponent("clear-\(effect.persistedIdentifier)-\(Int(time*1000)).png"))
                }
                finalPixels = frame.pixels
            }
            try require(finalPixels == openPixels, "Clearing did not restore exact original pixels.")
        }

        let effects = try checkEffects(device,renderer,input,output)
        let resources = try checkResourceReuse(device,renderer)

        // Both input AND output are native size, including pyramid rebuild cost.
        let nativeInput = try renderer.makePreviewTexture(width:3024,height:1964)
        let nativeTarget = try target(device,3024,1964,shared:false)
        let native = try timeRender(label: "Duo native") { i in
            var u = FoldUniforms(); u.progress = 0.02+Float(i%40)/41
            return try encode(renderer,nativeInput,nativeTarget,u)
        }
        let beforeCachedBenchmark = renderer.blurBuildCount
        let cached = try timeRender(label: "Duo cached") { i in
            var u = FoldUniforms(); u.progress = 0.02+Float(i%40)/41
            return try encode(renderer,nativeInput,nativeTarget,u,revision:2000)
        }
        try require(renderer.blurBuildCount == beforeCachedBenchmark+1, "Static native frames rebuilt the blur.")
        let effectTimes = try benchmarkEffects(device,renderer,nativeInput,nativeTarget)
        let report: [String: Any] = ["version":"1.0.0","gpu":device.name,"gradualOnset":gradualOnset,"clearTransitionChecks":clearChecks,"clearDurationSeconds":FoldVisualAnimation.clearDuration,"frameChecks":checkpoints,
            "effectCatalog":checkedEffects.map { ["id":$0.persistedIdentifier,"shaderIndex":Int($0.shaderIndex),
                "title":$0.title,"prefiltersSource":$0.needsPrefilteredSource] },
            "effectChecks":effects,"effectNativeGPUTimes":effectTimes,
            "resourceReuseChecks":resources,
            "effectNativeInputAndOutput":"3024 × 1964 for \(checkedEffects.count) of \(FoldEffect.allCases.count) effects",
            "pixelIdentityAndReopen":true,"opaqueAndClosedBlack":true,"reduceMotion":true,"enlargement":growth,
            "topContrastRatio":topRatio,"hingeContrastRatio":hingeRatio,
            "ninetyDegreeTopContrastRatio":ninetyRatio,"stationaryNinetyDegreesExactPixels":true,
            "cachedBlurPixelIdentity":true,"recycledSourceFreshness":true,"staticFramesBuildPyramidOnce":true,
            "cachedNativeGPUTimeMedianMS":cached.medianMS,
            "cachedNativeGPUTimeP95MS":cached.p95MS,"timingGate":timingMode,
            "sideFadePixels":edgeRamp(edges,horizontal:true),"topFadePixels":edgeRamp(edges,horizontal:false),
            "resolutionIndependentEdges":true,"threeInFlightFrames":true,
            "nativeInputAndOutput":"3024 × 1964","nativeGPUTimeMedianMS":native.medianMS,"nativeGPUTimeP95MS":native.p95MS,
            "note":"Includes blur pyramid and final pass. GPU-only timing excludes capture, window composition, display refresh, and physical lid movement. Best-of-three medians; by default each effect is gated at 2.5× the Duo median of the same run (Duo itself at a 12 ms sanity limit), --strict-timing enforces the absolute 6 ms budget on median and p95, --no-timing only records."]
        let json = try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try json.write(to:output.appendingPathComponent("render-check.json"))
        print(String(data:json,encoding:.utf8)!)

        if args.contains("--animation") || args.contains("--ghost-animation") {
            // --animation-size WxH renders the frames larger than the 960×624 website
            // media, for the App Store previews; the aspect stays that of the artwork.
            var animationWidth = 960, animationHeight = 624
            if let index = args.firstIndex(of:"--animation-size"), index+1 < args.count {
                let parts = args[index+1].lowercased().split(separator:"x").compactMap { Int($0) }
                try require(parts.count == 2 && parts[0] >= 160 && parts[1] >= 104 && parts[0] <= 4096 && parts[1] <= 4096,
                            "--animation-size expects WIDTHxHEIGHT between 160x104 and 4096x4096.")
                animationWidth = parts[0]; animationHeight = parts[1]
            }
            let animatedTarget = try target(device,animationWidth,animationHeight)
            for effect in checkedEffects where !args.contains("--ghost-animation") || effect == .ghost {
                let directory = output.appendingPathComponent("animation/\(effect.rawValue)")
                try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
                for frame in 0..<180 {
                    var u = FoldUniforms(); u.effect = effect.shaderIndex
                    if effect == .ghost {
                        let state = FoldVisualState.at(angle:105-65*pow(sin(Double(frame)/179 * .pi),2),reference:105)
                        u.progress = Float(state.progress);u.defocus = Float(state.defocus);u.tilt = Float(state.tilt); u.referenceAngle = Float(state.referenceAngle)
                    } else { u.progress = Float(pow(sin(Double(frame)/179 * .pi),2)) }
                    try save(render(renderer,input,animatedTarget,u),directory.appendingPathComponent(String(format:"frame-%03d.png",frame)))
                }
            }
        }
    }
}
