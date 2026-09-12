import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Louver: N slats each turn about their own centre line, so the black gaps
    /// open around fixed axes, every slat still carries its whole source band
    /// compressed, the top slat leads the hinge slat, intensity sets the turn
    /// rate, segments sets the slat count, softness blurs without moving edges,
    /// perspective tapers the receding half and shadow shades edge-on slats.
    static func checkLouver(_ device: MTLDevice, _ renderer: FoldRenderer,
                            _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = FoldEffect.louver.shaderIndex
        u.blur = 0; u.shadow = 0; u.perspective = 0; u.progress = 0.5
        let flat = try fixture(device,width:W,height:H) { _,_ in 200 }
        let slats = try render(renderer,flat,plate,u)

        // (a) Four slats, each centred on its own band axis, separated by black.
        let centres = brightRows(slats,above:100,rows:0..<H)
        try require(centres.count == 4,"Louver: expected 4 slats, found \(centres.count).")
        let axes = (0..<4).reversed().map { row((Double($0)+0.5)/4,H) }
        try require(zip(centres,axes).allSatisfy { abs($0-$1) <= 3 },
            "Louver: slats do not turn about their own centre lines: \(centres) vs \(axes).")
        let darkRows = (0..<H).filter { rowMean(slats,$0) < 30 }.count
        try require(darkRows > H/5 && darkRows < H*2/5,
            "Louver: the gaps between slats cover \(darkRows) of \(H) rows at half closure.")
        let gaps = louverDarkRuns(slats,below:30)
        try require(gaps.count == 5,"Louver: expected 5 dark strips (two half gaps at the borders), found \(gaps.count).")
        try require(gaps[1] >= gaps[2] && gaps[2] >= gaps[3] && gaps[1] > gaps[3]+3,
            "Louver: the top slat should lead the hinge slat; gaps top to hinge were \(gaps).")

        // Each slat still shows its entire source band, compressed and upright.
        let sawtooth = try fixture(device,width:W,height:H) { _,y in
            let height = 1-(Double(y)+0.5)/Double(H)
            let phase = height*4-floor(height*4)
            return UInt8(60+Int(190*phase))
        }
        let compressed = try render(renderer,sawtooth,plate,u)
        // The first and last rows of a slat are its feathered edges, so read
        // the extremes just inside them.
        var runs: [(top: Double, bottom: Double, peak: Double, trough: Double)] = []
        var current: [Double] = []
        for y in 0...H {
            let mean = y < H ? rowMean(compressed,y) : 0
            if mean > 30 { current.append(mean) } else if current.count >= 6 {
                runs.append((current.prefix(3).max()!,current.suffix(3).min()!,current.max()!,current.min()!)); current = []
            } else { current = [] }
        }
        try require(runs.count == 4,"Louver: the sawtooth source shows \(runs.count) slats instead of 4.")
        try require(runs.allSatisfy { $0.peak >= 225 && $0.trough <= 95 && $0.top > $0.bottom+100 },
            "Louver: slats do not carry their whole source band compressed and upright: \(runs).")

        // (b) Intensity 0 and 1 both render four valid slats, at different angles.
        u.intensity = 0
        let gentle = try render(renderer,flat,plate,u)
        u.intensity = 1
        let brisk = try render(renderer,flat,plate,u)
        u.intensity = 0.5
        let gentleDark = (0..<H).filter { rowMean(gentle,$0) < 30 }.count
        let briskDark = (0..<H).filter { rowMean(brisk,$0) < 30 }.count
        try require(brightRows(gentle,above:100,rows:0..<H).count == 4 && brightRows(brisk,above:100,rows:0..<H).count == 4,
            "Louver: an intensity extreme lost the four slats.")
        try require(gentleDark < darkRows-10 && briskDark > darkRows+10,
            "Louver: intensity does not scale the turn rate (dark rows \(gentleDark)/\(darkRows)/\(briskDark)).")
        try require(meanAbsDiff(gentle,brisk) >= 6,"Louver: intensity 0 and 1 render nearly the same frame.")

        // (c) The segment count is the slat count.
        u.segments = 2
        let two = brightRows(try render(renderer,flat,plate,u),above:100,rows:0..<H).count
        u.segments = 8
        let eightFrame = try render(renderer,flat,plate,u)
        let eight = brightRows(eightFrame,above:100,rows:0..<H).count
        u.segments = 4
        try require(two == 2 && eight == 8,"Louver: segments 2/8 rendered \(two)/\(eight) slats.")
        try require(meanAbsDiff(eightFrame,slats) >= 6,"Louver: eight slats look like four.")

        // (d) Softness blurs the slats but leaves their edges where they are.
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        let sharp = try render(renderer,checker,plate,u)
        u.blur = 0.65
        let softFlat = try render(renderer,flat,plate,u)
        let blurred = try render(renderer,checker,plate,u)
        u.blur = 0
        let softCentres = brightRows(softFlat,above:100,rows:0..<H)
        let softDark = (0..<H).filter { rowMean(softFlat,$0) < 30 }.count
        try require(softCentres.count == 4 && zip(softCentres,centres).allSatisfy { abs($0-$1) <= 2 } && abs(softDark-darkRows) <= 12,
            "Louver: softness moved the slat geometry (\(softCentres) vs \(centres), dark rows \(softDark) vs \(darkRows)).")
        let interior = (centres[1]-5)..<(centres[1]+5)
        let sharpVariation = variation(sharp,rows:interior), blurredVariation = variation(blurred,rows:interior)
        try require(blurredVariation < sharpVariation*0.5,
            "Louver: softness 0.65 does not defocus the turned slats (\(blurredVariation) vs \(sharpVariation)).")

        // Perspective tapers the receding half of each slat; without it the slat spans the width.
        let slatTop = centres[1]-louverHalfHeight(slats,centres[1])+3
        let slatBottom = centres[1]+louverHalfHeight(slats,centres[1])-3
        try require(litCount(slats,row:slatTop) >= W-2 && litCount(slats,row:slatBottom) >= W-2,
            "Louver: a slat without perspective does not span the full width.")
        u.perspective = 1
        let tapered = try render(renderer,flat,plate,u)
        u.perspective = 0
        let nearLit = litCount(tapered,row:slatTop), farLit = litCount(tapered,row:slatBottom)
        try require(nearLit >= W-2 && farLit <= W-20,
            "Louver: perspective does not taper the receding edge (near \(nearLit), far \(farLit) of \(W)).")

        // Shadow darkens a slat by its facing angle and lights its leading edge.
        let plain = try fixture(device,width:W,height:H) { _,_ in 128 }
        u.shadow = 1
        let shaded = try render(renderer,plain,plate,u)
        u.shadow = 0
        let body = rowMean(shaded,centres[1])
        let edgePeak = ((centres[1]-louverHalfHeight(shaded,centres[1]))...(centres[1]-1)).map { rowMean(shaded,$0) }.max()!
        try require(body < 120 && edgePeak > body+15,
            "Louver: shading is missing (body \(body), leading edge \(edgePeak)).")
        return ["louverSlatCentres":centres,"louverGapRowsTopToHinge":gaps,"louverDarkRowsByIntensity":[gentleDark,darkRows,briskDark],
                "louverSlatsBySegments":[two,4,eight],"louverInteriorVariationSharpVsSoft":[sharpVariation,blurredVariation],
                "louverTaperedLitColumnsNearFar":[nearLit,farLit],"louverShadedBodyAndEdge":[body,edgePeak]]
    }

    /// Lengths of consecutive rows whose mean sits below a level.
    static func louverDarkRuns(_ f: Frame, below level: Double) -> [Int] {
        var runs: [Int] = [], length = 0
        for y in 0..<f.height {
            if rowMean(f,y) < level { length += 1 } else if length > 0 { runs.append(length); length = 0 }
        }
        if length > 0 { runs.append(length) }
        return runs
    }

    /// Rows from a slat's centre up to its first dark row.
    static func louverHalfHeight(_ f: Frame, _ centre: Int) -> Int {
        var y = centre
        while y > 0 && rowMean(f,y-1) > 30 { y -= 1 }
        return centre-y
    }
}
