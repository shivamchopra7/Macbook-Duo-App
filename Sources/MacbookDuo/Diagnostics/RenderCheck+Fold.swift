import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Fold: the bottom half is the exact desktop, the top half folds down over
    /// it through a perspective-correct projective map, intensity moves the
    /// crease, segments are ignored, softness only defocuses, and the flap casts
    /// shadows and carries a specular band.
    static func checkFold(_ device: MTLDevice, _ renderer: FoldRenderer,
                          _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var report = try foldGeometry(device,renderer,plate,W,H)
        report.merge(try foldOptions(device,renderer,plate,W,H)) { a,_ in a }
        report.merge(try foldOptics(device,renderer,plate,W,H)) { a,_ in a }
        return report
    }

    private static func foldUniforms(_ progress: Float, shadow: Float = 0, blur: Float = 0) -> FoldUniforms {
        var u = FoldUniforms(); u.effect = FoldEffect.fold.shaderIndex
        u.progress = progress; u.shadow = shadow; u.blur = blur
        return u
    }

    /// The signature: top-edge content descends toward the crease, flips over the
    /// crease onto the bottom half, the bottom half stays exact, and the flap's
    /// rows are foreshortened by a perspective divide, stronger nearer the eye.
    private static func foldGeometry(_ device: MTLDevice, _ renderer: FoldRenderer,
                                     _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let marked = try fixture(device,width:W,height:H) { _,y in
            let height = 1-(Double(y)+0.5)/Double(H)
            return (height >= 0.955 && height <= 0.975) ? 250 : 60
        }
        var markedBytes = [UInt8](repeating:0,count:W*H*4)
        marked.getBytes(&markedBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        let crease = row(0.5,H)
        // A quarter closed: the band has come down but is still above the crease.
        let tilted = try render(renderer,marked,plate,foldUniforms(0.25))
        let early = brightRows(tilted,above:150,rows:0..<H)
        try require(early.count == 1,"Fold: the top-edge band did not appear exactly once while tilting.")
        try require(early[0] > row(0.95,H)+12 && early[0] < crease-40,
            "Fold: the tilting top half did not bring its top edge down toward the crease.")
        try require(identical(tilted,markedBytes,rows:row(0.48,H)..<H,columns:0..<W),
            "Fold: the bottom half moved while the top half tilted.")
        // Past the flip: the band lies mirrored on the bottom half, nothing above the crease.
        let folded = try render(renderer,marked,plate,foldUniforms(0.6))
        let over = brightRows(folded,above:150,rows:0..<H)
        try require(over.count == 1 && over[0] > row(0.35,H) && over[0] < row(0.05,H),
            "Fold: the top edge did not fold over onto the bottom half.")
        try require((0..<row(0.51,H)).allSatisfy { rowMean(folded,$0) < 2 },
            "Fold: something is still drawn above the crease after the flap folded over.")
        try require(identical(folded,markedBytes,rows:row(0.10,H)..<H,columns:0..<W),
            "Fold: the bottom half below the folded flap is not the exact desktop.")

        // Perspective: three ruled lines crowd together, more so near the crease
        // (farther from the eye) than near the tip.
        let ruled = try fixture(device,width:W,height:H) { _,y in
            let height = 1-(Double(y)+0.5)/Double(H)
            for line in [0.6,0.75,0.9] where abs(height-line) < 0.004 { return 240 }
            return 40
        }
        let lines = brightRows(try render(renderer,ruled,plate,foldUniforms(0.3)),
                               above:130,rows:0..<crease,columns:(W/2-40)..<(W/2+40))
        try require(lines.count == 3,"Fold: expected three source lines on the flap, measured \(lines).")
        let gapNearCrease = lines[2]-lines[1], gapNearTip = lines[1]-lines[0]
        let sourceGap = Int(0.15*Double(H))
        try require(gapNearCrease < sourceGap*85/100 && gapNearTip < sourceGap*85/100,
            "Fold: the flap's rows are not foreshortened.")
        try require(gapNearTip > gapNearCrease+3,
            "Fold: the foreshortening is affine; the projective divide is missing.")
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        var near = foldUniforms(0.3); near.perspective = 1
        var far = foldUniforms(0.3); far.perspective = 0
        let tipNear = topLit(try render(renderer,plain,plate,near),x:W/2)
        let tipFar = topLit(try render(renderer,plain,plate,far),x:W/2)
        try require(tipNear > tipFar+10,"Fold: perspective does not change the flap's foreshortening.")

        var descent: [Int] = []
        for step: Float in [0.1,0.2,0.3,0.4] {
            descent.append(topLit(try render(renderer,plain,plate,foldUniforms(step)),x:W/2))
        }
        try require(zip(descent,descent.dropFirst()).allSatisfy { $1 > $0+4 },
            "Fold: the top half does not fold down monotonically.")
        let edgeOn = topLit(try render(renderer,plain,plate,foldUniforms(0.5)),x:W/2)
        try require(edgeOn >= crease-8,"Fold: at half progress the flap has not passed the crease.")
        return ["foldTiltedBandRow":early[0],"foldFoldedBandRow":over[0],"foldCreaseRow":crease,
                "foldRuledLineRows":lines,"foldLineGapsTipToCrease":[gapNearTip,gapNearCrease],
                "foldTipRowByPerspective":["near":tipNear,"far":tipFar],
                "foldTipRowByProgress":descent+[edgeOn]]
    }

    /// Intensity moves the crease and hastens the fold; segments are ignored by a
    /// bi-fold; softness changes only optics.
    private static func foldOptions(_ device: MTLDevice, _ renderer: FoldRenderer,
                                    _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        var gentle = foldUniforms(0.5,shadow:0.65,blur:0.65); gentle.intensity = 0
        var strong = gentle; strong.intensity = 1
        let gentleFrame = try render(renderer,plain,plate,gentle)
        let strongFrame = try render(renderer,plain,plate,strong)
        let gentleMean = brightCentroid(gentleFrame,24), strongMean = brightCentroid(strongFrame,24)
        try require(gentleMean.count > W*H/3 && strongMean.count > W*H/3,
            "Fold: an intensity extreme lost most of the picture at half progress.")
        try require(meanAbsDiff(gentleFrame,strongFrame) >= 6,"Fold: intensity does not change the frame.")
        let gentleTop = topLit(gentleFrame,x:W/2), strongTop = topLit(strongFrame,x:W/2)
        try require(strongTop > gentleTop+40,"Fold: intensity does not deepen the fold.")
        try require(gentleTop < row(0.58,H)+6 && gentleTop > row(0.58,H)-90,
            "Fold: at intensity 0 the flap is not still tilting above a raised crease.")
        try require(abs(strongTop-row(0.42,H)) <= 6,"Fold: at intensity 1 the crease did not drop to 0.42.")

        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var two = foldUniforms(0.5,shadow:0.65,blur:0.65); two.segments = 2
        var eight = two; eight.segments = 8
        let twoFrame = try render(renderer,checker,plate,two)
        let eightFrame = try render(renderer,checker,plate,eight)
        try require(twoFrame.pixels == eightFrame.pixels,
            "Fold: a bi-fold has no segments, yet the segment option changed the frame.")

        var sharp = foldUniforms(0.35); sharp.defocus = 0.8
        var soft = sharp; soft.blur = 0.65
        let sharpFrame = try render(renderer,checker,plate,sharp)
        let softFrame = try render(renderer,checker,plate,soft)
        for x in [W/4,W/2,W*3/4] {
            try require(abs(topLit(sharpFrame,x:x)-topLit(softFrame,x:x)) <= 2,
                "Fold: softness moved the flap's silhouette.")
        }
        let flapRows = (topLit(sharpFrame,x:W/2)+10)..<(row(0.5,H)-6)
        let flapContrast = variation(softFrame,rows:flapRows)/variation(sharpFrame,rows:flapRows)
        try require(flapContrast < 0.9,"Fold: softness does not defocus the tilted flap.")
        let bottomRows = row(0.3,H)..<row(0.1,H)
        let bottomContrast = variation(softFrame,rows:bottomRows)/variation(sharpFrame,rows:bottomRows)
        try require(abs(bottomContrast-1) < 0.02,"Fold: softness blurred the flat bottom half.")
        return ["foldTopRowByIntensity":["gentle":gentleTop,"strong":strongTop],
                "foldIntensityFrameDifference":meanAbsDiff(gentleFrame,strongFrame),
                "foldSegmentsIgnored":true,"foldSoftnessFlapContrastRatio":flapContrast,
                "foldSoftnessBottomContrastRatio":bottomContrast]
    }

    /// The flap darkens the crease on the bottom half, drops a cast shadow ahead
    /// of its tip once it has folded over, and carries a specular band.
    private static func foldOptics(_ device: MTLDevice, _ renderer: FoldRenderer,
                                   _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let plain = try fixture(device,width:W,height:H) { _,_ in 160 }
        let unshaded = try render(renderer,plain,plate,foldUniforms(0.3))
        let shaded = try render(renderer,plain,plate,foldUniforms(0.3,shadow:1))
        let creaseRows = [row(0.495,H),row(0.46,H),row(0.40,H),row(0.15,H)]
        let contact = creaseRows.map { rowMean(unshaded,$0)-rowMean(shaded,$0) }
        try require(contact[0] >= 10 && contact[0] > contact[1] && contact[1] > contact[2] && abs(contact[3]) < 3,
            "Fold: the crease does not carry a contact shadow that fades down the bottom half.")

        let openBelow = try render(renderer,plain,plate,foldUniforms(0.5))
        let castBelow = try render(renderer,plain,plate,foldUniforms(0.5,shadow:1))
        let underTip = rowMean(castBelow,row(0.35,H))/rowMean(openBelow,row(0.35,H))
        let nearHinge = rowMean(castBelow,row(0.05,H))/rowMean(openBelow,row(0.05,H))
        try require(underTip < 0.8 && nearHinge > 0.9,
            "Fold: the folded flap does not cast a shadow ahead of its tip that clears by the hinge.")

        let grey = try fixture(device,width:W,height:H) { _,_ in 128 }
        let lit = try render(renderer,grey,plate,foldUniforms(0.3,shadow:1,blur:0.4))
        let flapRows = Array((topLit(lit,x:W/2)+6)..<(row(0.5,H)-4))
        let profile = flapRows.map { rowMean(lit,$0) }
        let peak = profile.max()!, peakIndex = profile.firstIndex(of:peak)!
        let median = profile.sorted()[profile.count/2]
        try require(peak > median+15,"Fold: no specular band on the tilted flap.")
        try require(peakIndex >= 4 && peakIndex <= profile.count-5,
            "Fold: the highlight sits on the flap's silhouette instead of across its face.")
        return ["foldCreaseContactShadow":contact,"foldCastShadowUnderTip":underTip,
                "foldCastShadowNearHinge":nearHinge,"foldSpecularPeak":peak,
                "foldSpecularPeakRow":flapRows[peakIndex],"foldFlapMedian":median]
    }
}
