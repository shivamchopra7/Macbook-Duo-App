import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// The pleat layout the Accordion shader derives from its uniforms, in height
    /// units: even (away) faces foreshorten, odd (toward) faces stay broad.
    struct AccordionLayout {
        let away: Double, toward: Double, stack: Double
        init(intensity: Double, perspective: Double, segments: Int, progress: Double) {
            let n = min(8, max(2, segments)), band = 1/Double(n)
            let thetaMax = min(40+70*intensity, 88)*Double.pi/180
            let theta = thetaMax*(1-(1-progress)*(1-progress))
            let phi = (6+10*perspective)*Double.pi/180
            away = band*max(cos(theta+phi), 0.05)/cos(phi)
            toward = band*cos(theta-phi)/cos(phi)
            stack = Double(n/2)*(away+toward)+(n%2 == 1 ? away : 0)
        }
        /// Height of the crease above pleat `index`, measured from the hinge.
        func creaseHeight(above index: Int) -> Double {
            Double((index+1)/2)*(away+toward)+((index+1)%2 == 1 ? away : 0)
        }
    }

    /// Accordion: each pleat is a linear stretch of its own source band whose
    /// screen height follows the fan geometry, the stack gathers monotonically
    /// toward the hinge, faces alternate dark and lit with ridge and valley
    /// creases, valleys recede at the sides, intensity scales the tilt, the
    /// segment count sets the pleat count, and softness blurs without moving anything.
    static func checkAccordion(_ device: MTLDevice, _ renderer: FoldRenderer,
                               _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let columns = (W/4)..<(W*3/4)
        let levels = [60, 120, 180, 240]
        let bands = try fixture(device,width:W,height:H) { _,y in
            let height = 1-(Double(y)+0.5)/Double(H)
            return UInt8(levels[min(3, Int(height*4))])
        }
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var u = FoldUniforms(); u.effect = FoldEffect.accordion.shaderIndex
        u.blur = 0; u.shadow = 0; u.progress = 0.5

        // (a) Signature geometry: scanning up from the hinge, the four source
        // bands appear in order with the heights the fan assigns them.
        func crossings(_ frame: Frame) -> [Int] {
            var found: [Int] = []
            for level in 1..<levels.count {
                let midpoint = Double(levels[level-1]+levels[level])/2
                var row = H-1
                while row >= 0 && rowMean(frame,row,columns) < midpoint { row -= 1 }
                found.append(row)
            }
            return found
        }
        let layout = AccordionLayout(intensity:Double(u.intensity),perspective:Double(u.perspective),segments:4,progress:0.5)
        let folded = try render(renderer,bands,plate,u)
        let measured = crossings(folded)
        let expected = (0..<3).map { row(layout.creaseHeight(above:$0),H) }
        try require(zip(measured,expected).allSatisfy { abs($0-$1) <= 3 },
            "Accordion: pleat creases at rows \(measured) do not match the fan geometry \(expected).")
        let stackTop = topLit(folded,x:W/2)
        try require(abs(stackTop-row(layout.stack,H)) <= 3,
            "Accordion: the stack top at row \(stackTop) is not at the gathered height \(row(layout.stack,H)).")
        try require((0..<max(0,stackTop-3)).allSatisfy { rowMean(folded,$0) < 2 },
            "Accordion: content survives above the gathered stack.")
        let awayRows = H-1-measured[0], towardRows = measured[0]-measured[1]
        try require(Double(awayRows) < Double(towardRows)*0.7 && awayRows >= 8,
            "Accordion: the away face (\(awayRows) rows) is not foreshortened against the toward face (\(towardRows) rows).")
        // Valleys recede: a row at a valley is narrower than a row at a ridge.
        let ridgeRow = row(layout.away-0.004,H), valleyRow = row(layout.away+layout.toward-0.004,H)
        let ridgeWidth = litCount(folded,row:ridgeRow), valleyWidth = litCount(folded,row:valleyRow)
        try require(valleyWidth <= ridgeWidth-10,
            "Accordion: the valley row (\(valleyWidth) lit) does not draw in against the ridge row (\(ridgeWidth) lit).")

        // The stack gathers monotonically toward the hinge.
        var descent: [Int] = []
        for step: Float in [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8] {
            u.progress = step
            descent.append(topLit(try render(renderer,plain,plate,u),x:W/2))
        }
        try require(zip(descent,descent.dropFirst()).allSatisfy { $1 > $0+4 },
            "Accordion: the stack does not gather toward the hinge: \(descent).")

        // Shading: away faces dark, toward faces lit with a ridge edge and a valley seam.
        u.progress = 0.5; u.shadow = 1
        let shaded = try render(renderer,plain,plate,u)
        let awayMean = rowMean(shaded,row(layout.away*0.5,H),columns)
        let towardMean = rowMean(shaded,row(layout.away+layout.toward*0.5,H),columns)
        try require(awayMean < towardMean*0.8,
            "Accordion: the away face (\(awayMean)) is not darker than the toward face (\(towardMean)).")
        let ridgeCrease = row(layout.away,H), valleyCrease = row(layout.away+layout.toward,H)
        let ridgePeak = ((ridgeCrease-4)...(ridgeCrease+1)).map { rowMean(shaded,$0,columns) }.max()!
        let valleyDip = ((valleyCrease-1)...(valleyCrease+4)).map { rowMean(shaded,$0,columns) }.min()!
        try require(ridgePeak >= towardMean+6,"Accordion: the ridge crease is not lit (\(ridgePeak) vs \(towardMean)).")
        try require(valleyDip <= towardMean-12,"Accordion: the valley crease has no seam (\(valleyDip) vs \(towardMean)).")

        // (b) Intensity 0 and 1 both render a usable fan, tilted by different amounts.
        var gentle = u; gentle.intensity = 0; gentle.shadow = 0.65
        var steep = u; steep.intensity = 1; steep.shadow = 0.65
        let gentleFrame = try render(renderer,plain,plate,gentle), steepFrame = try render(renderer,plain,plate,steep)
        let gentleTop = topLit(gentleFrame,x:W/2), steepTop = topLit(steepFrame,x:W/2)
        let gentleLayout = AccordionLayout(intensity:0,perspective:Double(u.perspective),segments:4,progress:0.5)
        let steepLayout = AccordionLayout(intensity:1,perspective:Double(u.perspective),segments:4,progress:0.5)
        try require(abs(gentleTop-row(gentleLayout.stack,H)) <= 3 && abs(steepTop-row(steepLayout.stack,H)) <= 3,
            "Accordion: intensity changed the stack height away from the fan geometry.")
        try require(steepTop >= gentleTop+100,"Accordion: intensity does not steepen the fan.")
        try require(brightCount(gentleFrame,100) > W*H/4 && brightCount(steepFrame,100) > W*H/10,
            "Accordion: an intensity extreme hid the display.")
        let intensityDifference = meanAbsDiff(gentleFrame,steepFrame)
        try require(intensityDifference >= 10,"Accordion: intensity extremes render alike.")

        // (c) Segments: each toward face is a lit band, so the count follows N/2.
        var pleatCounts: [Int: Int] = [:]
        var segmentFrames: [Int: Frame] = [:]
        for segments in [2,4,6,8] {
            var v = u; v.segments = UInt32(segments); v.shadow = 1
            let frame = try render(renderer,plain,plate,v)
            segmentFrames[segments] = frame
            let lit = brightRows(frame,above:150,rows:0..<H,columns:columns).count
            try require(lit == segments/2,"Accordion: \(segments) segments drew \(lit) lit faces instead of \(segments/2).")
            pleatCounts[segments] = lit
        }
        try require(meanAbsDiff(segmentFrames[4]!,segmentFrames[8]!) >= 6,"Accordion: the segment count barely changes the frame.")

        // (d) Softness blurs the faces without moving creases or the stack top.
        var sharp = u; sharp.shadow = 0; sharp.blur = 0
        var soft = u; soft.shadow = 0; soft.blur = 0.65
        let sharpBands = try render(renderer,bands,plate,sharp), softBands = try render(renderer,bands,plate,soft)
        let sharpCrossings = crossings(sharpBands), softCrossings = crossings(softBands)
        try require(zip(sharpCrossings,softCrossings).allSatisfy { abs($0-$1) <= 3 },
            "Accordion: softness moved the creases \(sharpCrossings) -> \(softCrossings).")
        try require(abs(topLit(sharpBands,x:W/2)-topLit(softBands,x:W/2)) <= 3,
            "Accordion: softness moved the stack top.")
        let sharpChecker = try render(renderer,checker,plate,sharp), softChecker = try render(renderer,checker,plate,soft)
        let faceRows = (row(layout.away+layout.toward*0.6,H))..<(row(layout.away+layout.toward*0.4,H))
        let sharpDetail = variation(sharpChecker,rows:faceRows), softDetail = variation(softChecker,rows:faceRows)
        try require(sharpDetail > softDetail+4,
            "Accordion: softness did not blur the toward face (\(sharpDetail) vs \(softDetail)).")
        try require(meanAbsDiff(sharpChecker,softChecker) >= 2,"Accordion: softness barely changes the frame.")

        return ["accordionCreaseRows":measured,"accordionExpectedCreaseRows":expected,
                "accordionStackTopRow":stackTop,"accordionAwayTowardRows":[awayRows,towardRows],
                "accordionRidgeValleyWidths":[ridgeWidth,valleyWidth],
                "accordionStackTopByProgress":descent,
                "accordionFaceShading":["away":awayMean,"toward":towardMean,"ridge":ridgePeak,"valley":valleyDip],
                "accordionIntensityStackTops":[gentleTop,steepTop],"accordionIntensityDifference":intensityDifference,
                "accordionLitFacesBySegments":pleatCounts.map { ["segments":$0.key,"litFaces":$0.value] },
                "accordionSoftnessDetail":[sharpDetail,softDetail]]
    }
}
