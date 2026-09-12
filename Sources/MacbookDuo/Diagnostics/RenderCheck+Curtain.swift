import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Curtain: two drapes slide in from the sides and meet at p = 0.85 while the
    /// centre stays the exact desktop; the cloth carries swept content compressed
    /// toward the screen edge (more so at high intensity), lays one lit crest per
    /// pleat, sags between rings with perspective, drops a shadow beside its hem,
    /// and softness only defocuses the cloth without moving anything.
    static func checkCurtain(_ device: MTLDevice, _ renderer: FoldRenderer,
                             _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let aspect = Double(W)/Double(H)
        let feather = 1.5/Double(H)
        func edgeColumns(_ p: Double) -> Double { min(p/0.85,1)*(0.5+2*feather/aspect)*Double(W) }

        // The bare centre is the exact desktop between two leading edges that
        // travel from the screen edges to the middle and meet at p = 0.85.
        let ramp = try fixture(device,width:W,height:H) { x,_ in UInt8(30+200*x/(W-1)) }
        var rampBytes = [UInt8](repeating:0,count:W*H*4)
        ramp.getBytes(&rampBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        var u = FoldUniforms(); u.effect = FoldEffect.curtain.shaderIndex
        u.blur = 0; u.shadow = 0; u.perspective = 0
        func exactCentreStart(_ frame: Frame) -> Int {
            for c in 0...(W/2) where identical(frame,rampBytes,rows:0..<H,columns:c..<(W-c)) { return c }
            return W/2
        }
        var travel: [[String: Any]] = []
        var previousStart = -1
        for p: Float in [0.2,0.35,0.5,0.65,0.8,0.85] {
            u.progress = p
            let start = exactCentreStart(try render(renderer,ramp,plate,u))
            let expected = edgeColumns(Double(p))
            if p < 0.85 {
                try require(abs(Double(start)-expected) <= 3,
                    "Curtain: at p=\(p) the leading edge sits at column \(start), expected \(Int(expected)).")
            } else {
                try require(start >= W/2-1,"Curtain: the drapes did not meet at p=0.85.")
            }
            try require(start > previousStart,"Curtain: the leading edges do not travel monotonically toward the centre.")
            previousStart = start
            travel.append(["progress":Double(p),"exactCentreFromColumn":start,"expectedEdgeColumn":expected])
        }

        // A bright bar just inside the centre stays exact there and reappears on
        // the left drape, compressed toward the screen edge; the right drape has
        // swept none of it.
        let bar = try fixture(device,width:W,height:H) { x,_ in (x >= W*30/100 && x < W*33/100) ? 250 : 60 }
        var barBytes = [UInt8](repeating:0,count:W*H*4)
        bar.getBytes(&barBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        func barCopy(_ frame: Frame, threshold: Int = 150) -> (centre: Double, count: Int) {
            let columns = (0..<Int(edgeColumns(0.5))).filter { frame.gray($0,H/2) > threshold }
            return (columns.isEmpty ? -1 : Double(columns.reduce(0,+))/Double(columns.count),columns.count)
        }
        u.progress = 0.5
        let swept = try render(renderer,bar,plate,u)
        try require(identical(swept,barBytes,rows:0..<H,columns:(W*30/100)..<(W*70/100)),
            "Curtain: the bare centre is not the exact desktop.")
        let copy = barCopy(swept)
        let gatherHalf = 1+0.7*(0.5/0.85)
        let expectedCopy = 0.315/gatherHalf*Double(W)
        try require(copy.count >= 8 && copy.count <= 24 && abs(copy.centre-expectedCopy) <= 10,
            "Curtain: the drape did not carry the swept bar compressed toward the screen edge (\(copy)).")
        try require((W/2..<W).allSatisfy { swept.gray($0,H/2) < 150 },
            "Curtain: the right drape shows content it never swept.")

        // Intensity: stronger gather pulls the copy further toward the edge while
        // the leading edge and the bare centre are unchanged.
        u.intensity = 0
        let mild = try render(renderer,bar,plate,u)
        u.intensity = 1
        let strong = try render(renderer,bar,plate,u)
        u.intensity = 0.5
        let mildCopy = barCopy(mild), strongCopy = barCopy(strong)
        try require(mildCopy.count > 0 && strongCopy.count > 0 && strongCopy.centre < mildCopy.centre-40,
            "Curtain: intensity does not change how far the cloth gathers (\(mildCopy) vs \(strongCopy)).")
        for frame in [mild,strong] {
            try require(identical(frame,barBytes,rows:0..<H,columns:(W*30/100)..<(W*70/100)),
                "Curtain: intensity moved the leading edge or reshaded the bare centre.")
        }
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var tuned = FoldUniforms(); tuned.effect = FoldEffect.curtain.shaderIndex; tuned.progress = 0.5
        tuned.intensity = 0
        let mildChecker = try render(renderer,checker,plate,tuned)
        tuned.intensity = 1
        let strongChecker = try render(renderer,checker,plate,tuned)
        let intensitySeparation = meanAbsDiff(mildChecker,strongChecker)
        try require(intensitySeparation >= 6,"Curtain: intensity 0 and 1 render nearly the same frame.")

        // Segments: one lit crest per pleat across the cloth, stopping short of
        // the ring at the leading edge, which the hem shadow darkens.
        let plain = try fixture(device,width:W,height:H) { _,_ in 128 }
        var pleatBands: [String: Int] = [:]
        for segments: UInt32 in [3,6] {
            var v = FoldUniforms(); v.effect = FoldEffect.curtain.shaderIndex
            v.blur = 0; v.shadow = 1; v.perspective = 0; v.progress = 0.5; v.segments = segments
            let lit = try render(renderer,plain,plate,v)
            var bands = 0, inside = false
            for x in 0..<Int(edgeColumns(0.5)*(1-0.6/Double(segments))) {
                let bright = lit.gray(x,H/2) > 136
                if bright && !inside { bands += 1 }
                inside = bright
            }
            try require(bands == Int(segments),
                "Curtain: \(segments) pleats drew \(bands) lit crests.")
            pleatBands["segments\(segments)"] = bands
        }

        // Perspective sags the cloth between rings; the top of a line near the
        // top of the source drops on the drape by up to a dozen rows.
        let lined = try fixture(device,width:W,height:H) { _,y in (y >= H*2/100 && y < H*4/100) ? 250 : 60 }
        u.perspective = 0
        let taut = try render(renderer,lined,plate,u)
        u.perspective = 1
        let sagging = try render(renderer,lined,plate,u)
        u.perspective = 0
        let drapeColumns = 0..<Int(edgeColumns(0.5))-4
        let tautTops = drapeColumns.map { topLit(taut,x:$0,threshold:150) }
        let saggingTops = drapeColumns.map { topLit(sagging,x:$0,threshold:150) }
        try require(tautTops.allSatisfy { $0 == H*2/100 },"Curtain: without perspective the cloth top moved.")
        try require(saggingTops.max()! >= H*2/100+8 && saggingTops.min()! >= H*2/100,
            "Curtain: perspective does not sag the cloth between its rings.")

        // The hem drops a shadow on the bare desktop that fades away from it.
        let bright = try fixture(device,width:W,height:H) { _,_ in 200 }
        u.shadow = 1
        let shadowed = try render(renderer,bright,plate,u)
        u.shadow = 0
        let unshadowed = try render(renderer,bright,plate,u)
        let hem = Int(edgeColumns(0.5))
        let contact = [shadowed.gray(hem+6,H/2),shadowed.gray(hem+56,H/2),unshadowed.gray(hem+6,H/2)]
        try require(contact[0] <= 165 && contact[1] >= 195 && contact[2] == 200,
            "Curtain: the hem does not drop a fading shadow on the bare desktop (\(contact)).")

        // Softness defocuses the compressed cloth without moving the copy or the edge.
        u.defocus = 1
        u.blur = 0
        let sharp = try render(renderer,bar,plate,u)
        u.blur = 0.65
        let soft = try render(renderer,bar,plate,u)
        u.blur = 0; u.defocus = -1
        let sharpCopy = barCopy(sharp,threshold:120), softCopy = barCopy(soft,threshold:120)
        try require(sharpCopy.count > 0 && softCopy.count > 0 && abs(sharpCopy.centre-softCopy.centre) <= 3,
            "Curtain: softness moved the cloth (\(sharpCopy) vs \(softCopy)).")
        func rampColumns(_ frame: Frame) -> Int {
            (0..<Int(edgeColumns(0.5))).filter { frame.gray($0,H/2) > 90 && frame.gray($0,H/2) < 220 }.count
        }
        let sharpRamp = rampColumns(sharp), softRamp = rampColumns(soft)
        try require(softRamp >= sharpRamp+6,"Curtain: softness does not defocus the cloth (\(sharpRamp) vs \(softRamp)).")
        for frame in [sharp,soft] {
            try require(identical(frame,barBytes,rows:0..<H,columns:(W*31/100)..<(W*69/100)),
                "Curtain: softness reshaded or moved the bare centre.")
        }
        return ["curtainLeadingEdgeTravel":travel,
                "curtainSweptBarCopy":["centre":copy.centre,"columns":copy.count,"expectedCentre":expectedCopy],
                "curtainIntensityBarCentres":["mild":mildCopy.centre,"strong":strongCopy.centre],
                "curtainIntensitySeparation":intensitySeparation,
                "curtainPleatCrests":pleatBands,
                "curtainSagRows":["taut":tautTops.max()!,"sagging":saggingTops.max()!],
                "curtainHemShadowProfile":contact,
                "curtainSoftnessRampColumns":["sharp":sharpRamp,"soft":softRamp]]
    }
}
