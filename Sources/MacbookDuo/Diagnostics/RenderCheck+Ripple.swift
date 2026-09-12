import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Ripple: a round sink on the hinge centre that widens with the angle,
    /// content that slides down toward it, concentric ring shading that travels
    /// outward, intensity that scales the liquid, no segment dependence, and
    /// softness that changes only the optics.
    static func checkRipple(_ device: MTLDevice, _ renderer: FoldRenderer,
                            _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var report: [String: Any] = [:]
        try report.merge(checkRippleSink(device,renderer,plate,W,H)) { a,_ in a }
        try report.merge(checkRippleRings(device,renderer,plate,W,H)) { a,_ in a }
        try report.merge(checkRippleOptions(device,renderer,plate,W,H)) { a,_ in a }
        return report
    }

    /// Rows of near-black pixels running up from the hinge in one column.
    static func rippleDrainRun(_ f: Frame, x: Int) -> Int {
        var run = 0
        for y in stride(from:f.height-1,through:0,by:-1) {
            guard f.gray(x,y) < 24 else { break }
            run += 1
        }
        return run
    }

    /// Rows of local brightness maxima along one column, with a minimum
    /// prominence against the rows a quarter wavelength either side. A flat
    /// crest spanning several rows is collapsed to its centre.
    static func rippleCrests(_ f: Frame, x: Int, rows: Range<Int>, prominence: Int = 5) -> [Int] {
        let reach = 20
        let peaks = rows.filter { y in
            guard y-reach >= 0, y+reach < f.height else { return false }
            let value = f.gray(x,y)
            let neighbours = [f.gray(x,y-reach),f.gray(x,y+reach)]
            let flanks = [f.gray(x,y-1),f.gray(x,y+1)]
            return neighbours.allSatisfy { value >= $0+prominence } && flanks.allSatisfy { value >= $0 }
        }
        var groups: [[Int]] = []
        for y in peaks {
            if let last = groups.last?.last, y == last+1 { groups[groups.count-1].append(y) } else { groups.append([y]) }
        }
        return groups.map { $0.reduce(0,+)/$0.count }
    }

    /// A wide band across the image at one height, on a dim ground.
    static func rippleBand(_ device: MTLDevice, _ W: Int, _ H: Int, at height: Double) throws -> MTLTexture {
        try fixture(device,width:W,height:H) { _,y in
            let h = 1-(Double(y)+0.5)/Double(H)
            return abs(h-height) <= 0.01 ? 250 : 60
        }
    }

    /// The sink: a round hole at the hinge centre, the picture lit above it,
    /// growing monotonically, and content sliding down toward it.
    static func checkRippleSink(_ device: MTLDevice, _ renderer: FoldRenderer,
                                _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = FoldEffect.ripple.shaderIndex
        u.blur = 0; u.shadow = 0; u.progress = 0.5
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        let aspect = Double(W)/Double(H)
        let sunk = try render(renderer,plain,plate,u)
        let holeRows = rippleDrainRun(sunk,x:W/2)
        try require(holeRows > H*12/100 && holeRows < H*45/100,
            "Ripple: the sink at the hinge has the wrong size at half closure: \(holeRows) rows.")
        try require(sunk.gray(W/2,row(0.5,H)) > 150 && sunk.gray(W/4,row(0.5,H)) > 150,
            "Ripple: the picture above the sink is not lit.")
        // Aspect-corrected roundness: 0.6 of the radius sideways leaves 0.8 of it upward.
        let radius = Double(holeRows)/Double(H)
        let sideways = Int(0.6*radius/aspect*Double(W))
        let expected = 0.8*Double(holeRows)
        let flanks = [rippleDrainRun(sunk,x:W/2-sideways),rippleDrainRun(sunk,x:W/2+sideways)]
        try require(flanks.allSatisfy { abs(Double($0)-expected) <= 6 },
            "Ripple: the sink is not a circle centred on the hinge: \(flanks) versus \(expected).")

        var growth: [Int] = []
        for step: Float in [0.2,0.35,0.5,0.65,0.8] {
            u.progress = step
            growth.append(rippleDrainRun(try render(renderer,plain,plate,u),x:W/2))
        }
        try require(zip(growth,growth.dropFirst()).allSatisfy { $1 > $0+4 },
            "Ripple: the sink does not widen with the angle: \(growth).")

        // A marker band from mid-height drains toward the hinge along the centre.
        let band = try rippleBand(device,W,H,at:0.56)
        let columns = (W/2-20)..<(W/2+20)
        u.progress = 0
        let rest = brightRows(try render(renderer,band,plate,u),above:150,rows:0..<H,columns:columns)
        u.progress = 0.4
        let drained = brightRows(try render(renderer,band,plate,u),above:150,rows:0..<H,columns:columns)
        try require(rest.count == 1 && drained.count == 1,
            "Ripple: expected one marker band, measured \(rest) and \(drained).")
        try require(drained[0] >= rest[0]+8 && drained[0] < H-holeRows,
            "Ripple: content did not slide down toward the sink.")
        return ["rippleSinkRowsAtHalf":holeRows,"rippleSinkFlankRows":flanks,
                "rippleSinkRowsByProgress":growth,"rippleBandRowRestAndDrained":[rest[0],drained[0]]]
    }

    /// Rings: periodic crest shading up the centre line, concentric about the
    /// hinge centre, travelling outward as the angle grows.
    static func checkRippleRings(_ device: MTLDevice, _ renderer: FoldRenderer,
                                 _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = FoldEffect.ripple.shaderIndex
        u.blur = 0; u.shadow = 1; u.progress = 0.5
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        let aspect = Double(W)/Double(H)
        let lit = try render(renderer,plain,plate,u)
        let holeTop = H-rippleDrainRun(lit,x:W/2)
        let crests = rippleCrests(lit,x:W/2,rows:row(0.95,H)..<(holeTop-8))
        try require(crests.count >= 3,"Ripple: fewer than three ring crests up the centre line: \(crests).")

        // The brightest crest on the centre line reappears at the same radius
        // along a ray 60 degrees from the hinge line.
        let strongest = crests.max { lit.gray(W/2,$0) < lit.gray(W/2,$1) }!
        let crestRadius = (Double(H)-Double(strongest)-0.5)/Double(H)
        var best = (radius: 0.0, value: -1)
        for offset in stride(from:-0.05,through:0.05,by:0.001) {
            let r = crestRadius+offset
            let x = Int((0.5+r*cos(Double.pi/3)/aspect)*Double(W))
            let y = Int((1-r*sin(Double.pi/3))*Double(H))
            guard x >= 0, x < W, y >= 0, y < H else { continue }
            let value = lit.gray(x,y)
            if value > best.value { best = (r,value) }
        }
        let concentricError = abs(best.radius-crestRadius)
        try require(concentricError <= 0.006,
            "Ripple: rings are not concentric about the hinge centre (radius error \(concentricError)).")

        // The crest nearest 40% height moves outward between two nearby angles.
        u.progress = 0.35
        let early = rippleCrests(try render(renderer,plain,plate,u),x:W/2,rows:row(0.9,H)..<row(0.12,H))
        u.progress = 0.38
        let later = rippleCrests(try render(renderer,plain,plate,u),x:W/2,rows:row(0.9,H)..<row(0.12,H))
        guard let tracked = early.min(by:{ abs($0-row(0.4,H)) < abs($1-row(0.4,H)) }),
              let moved = later.min(by:{ abs($0-tracked) < abs($1-tracked) }) else {
            throw AppError.message("Ripple: no crest to track near 40% height.")
        }
        let travel = tracked-moved
        try require(travel >= 3 && travel <= 16,"Ripple: rings do not travel outward (\(travel) rows).")
        return ["rippleCrestRowsAtHalf":crests,"rippleConcentricRadiusError":concentricError,
                "rippleCrestTravelRows":travel]
    }

    /// Options: intensity changes the drain and the wave while both frames stay
    /// valid, segments leave the frame untouched, softness blurs without moving.
    static func checkRippleOptions(_ device: MTLDevice, _ renderer: FoldRenderer,
                                   _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var u = FoldUniforms(); u.effect = FoldEffect.ripple.shaderIndex
        u.progress = 0.5
        u.intensity = 0
        let calm = try render(renderer,checker,plate,u)
        u.intensity = 1
        let wild = try render(renderer,checker,plate,u)
        let intensitySeparation = meanAbsDiff(calm,wild)
        try require(intensitySeparation >= 3,"Ripple: intensity 0 and 1 render nearly the same frame.")
        for (name,frame) in [("0",calm),("1",wild)] {
            try require(brightCount(frame,100) > W*H*15/100,"Ripple: intensity \(name) hid most of the picture.")
        }
        let band = try rippleBand(device,W,H,at:0.56)
        let columns = (W/2-20)..<(W/2+20)
        u.blur = 0; u.shadow = 0; u.progress = 0.4
        var bandRows: [Int] = []
        for intensity: Float in [0,1] {
            u.intensity = intensity
            let rows = brightRows(try render(renderer,band,plate,u),above:150,rows:0..<H,columns:columns)
            try require(rows.count == 1,"Ripple: intensity \(intensity) split the marker band: \(rows).")
            bandRows.append(rows[0])
        }
        try require(bandRows[1] >= bandRows[0]+4,"Ripple: intensity does not strengthen the drain.")

        u = FoldUniforms(); u.effect = FoldEffect.ripple.shaderIndex; u.progress = 0.5
        u.segments = 2
        let two = try render(renderer,checker,plate,u)
        u.segments = 8
        let eight = try render(renderer,checker,plate,u)
        try require(two.pixels == eight.pixels,"Ripple: the segment count changed a continuous liquid.")

        u.segments = 4; u.shadow = 0; u.blur = 0
        let sharp = try render(renderer,checker,plate,u)
        u.blur = 0.65
        let soft = try render(renderer,checker,plate,u)
        let rows = row(0.62,H)..<row(0.45,H)
        let softnessRatio = variation(soft,rows:rows)/variation(sharp,rows:rows)
        try require(softnessRatio < 0.92,"Ripple: softness does not defocus the liquid.")
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        var sinkRows: [Int] = [], bandCentres: [Int] = []
        for blur: Float in [0,0.65] {
            u.blur = blur
            sinkRows.append(rippleDrainRun(try render(renderer,plain,plate,u),x:W/2))
            let centre = brightRows(try render(renderer,band,plate,u),above:150,rows:0..<H,columns:columns)
            try require(centre.count == 1,"Ripple: softness \(blur) split the marker band: \(centre).")
            bandCentres.append(centre[0])
        }
        try require(abs(sinkRows[0]-sinkRows[1]) <= 8 && abs(bandCentres[0]-bandCentres[1]) <= 3,
            "Ripple: softness moved the geometry: sink \(sinkRows), band \(bandCentres).")
        return ["rippleIntensitySeparation":intensitySeparation,"rippleIntensityBandRows":bandRows,
                "rippleSegmentsIndependent":true,"rippleSoftnessContrastRatio":softnessRatio,
                "rippleSoftnessSinkRows":sinkRows,"rippleSoftnessBandRows":bandCentres]
    }
}
