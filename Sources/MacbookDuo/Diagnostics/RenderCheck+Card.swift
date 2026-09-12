import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// The Card shader's camera and hinge, mirrored so the checks can predict
    /// where a card point lands on screen and how much a screen row is scaled.
    struct CardModel {
        static let eyeY = 0.55
        static let maxAngle = 85 * Double.pi/180
        let angle: Double
        let distance: Double
        init(progress: Double, intensity: Double = 0.5, perspective: Double = 0.7) {
            let bias = 2*intensity-1
            let k = bias >= 0 ? 2.5*bias : 0.75*bias
            angle = Self.maxAngle*progress*(1+k)/(1+k*progress)
            distance = 2.6-1.3*perspective
        }
        /// Screen height (fraction above the hinge) of the card point at height `h`.
        func screenHeight(ofCard h: Double) -> Double {
            let y = h*cos(angle), z = -h*sin(angle)
            let t = distance/(distance-z)
            return Self.eyeY+t*(y-Self.eyeY)
        }
        /// Ray parameter to the card for a screen row: horizontal source scale.
        func rayScale(atScreen sy: Double) -> Double {
            let num = Self.eyeY*sin(angle)+distance*cos(angle)
            return num/max(num-sy*sin(angle),1e-4)
        }
    }

    /// Card: one rigid card in true perspective. The top edge, three ruled lines
    /// and the horizontal scale land where the ray/plane model predicts; the top
    /// narrows and descends monotonically; rays that miss the card are black;
    /// shading darkens with tilt and a sheen sweeps toward the hinge. Intensity
    /// changes the tilt, segments change nothing, softness changes only blur.
    static func checkCard(_ device: MTLDevice, _ renderer: FoldRenderer,
                          _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = FoldEffect.card.shaderIndex
        u.blur = 0; u.shadow = 0; u.progress = 0.5
        let model = CardModel(progress: 0.5)
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        let tipped = try render(renderer,plain,plate,u)
        let topRow = topLit(tipped,x:W/2)
        let expectedTop = row(model.screenHeight(ofCard:1),H)
        try require(abs(topRow-expectedTop) <= 4,
            "Card: the top edge landed on row \(topRow), the perspective model predicts \(expectedTop).")
        try require((0..<max(0,topRow-8)).allSatisfy { rowMean(tipped,$0) < 1 },
            "Card: rays that miss the card are not dark.")
        // A trapezoid: full width at the hinge, narrowed by the ray scale near the top.
        let hingeWidth = litCount(tipped,row:H-2)
        try require(hingeWidth >= W-4,"Card: the hinge edge is not anchored at full width.")
        let upperHeight = model.screenHeight(ofCard:0.9)
        let upperWidth = litCount(tipped,row:row(upperHeight,H))
        let predictedWidth = Double(W)/model.rayScale(atScreen:upperHeight)
        try require(abs(Double(upperWidth)-predictedWidth) < Double(W)*0.025,
            "Card: the upper width \(upperWidth) does not match the trapezoid width \(Int(predictedWidth)).")

        // Ruled source lines crowd together toward the receding top edge.
        let ruled = try fixture(device,width:W,height:H) { _,y in
            let height = 1-(Double(y)+0.5)/Double(H)
            for line in [0.25,0.5,0.75] where abs(height-line) < 0.004 { return 240 }
            return 40
        }
        let foreshortened = try render(renderer,ruled,plate,u)
        let lines = brightRows(foreshortened,above:130,rows:0..<H,columns:(W/2-40)..<(W/2+40))
        try require(lines.count == 3,"Card: expected three rigid source lines, measured \(lines).")
        let predictedLines = [0.75,0.5,0.25].map { row(model.screenHeight(ofCard:$0),H) }
        try require(zip(lines,predictedLines).allSatisfy { abs($0-$1) <= 4 },
            "Card: source lines \(lines) are not where the plane projection puts them \(predictedLines).")
        let gaps = [H-1-lines[2],lines[2]-lines[1],lines[1]-lines[0]]
        try require(gaps[0] > gaps[1]+6 && gaps[1] > gaps[2]+6,"Card: content is not foreshortened toward the top.")

        // Horizontal content scales by the same ray parameter as the silhouette.
        let horizontal = try fixture(device,width:W,height:H) { x,_ in UInt8(Double(x)*255/Double(W-1)) }
        let scaled = try render(renderer,horizontal,plate,u)
        // The gradient between two columns gives the scale directly, so the
        // additive sheen band cannot bias the read.
        var scaleChecks: [[String: Double]] = []
        for cardHeight in [0.2,0.5,0.8] {
            let sy = model.screenHeight(ofCard:cardHeight)
            let y = row(sy,H), expected = model.rayScale(atScreen:sy)
            let left = Double(scaled.gray(W/4,y)), right = Double(scaled.gray(W*3/4,y))
            let measured = (right-left)/255/0.5
            try require(abs(measured-expected) < 0.025,
                "Card: horizontal content at height \(cardHeight) is scaled by \(measured) instead of \(expected).")
            scaleChecks.append(["cardHeight":cardHeight,"measuredScale":measured,"predictedScale":expected])
        }

        var descent: [Int] = []
        for step: Float in [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8] {
            u.progress = step
            descent.append(topLit(try render(renderer,plain,plate,u),x:W/2))
        }
        try require(zip(descent,descent.dropFirst()).allSatisfy { $1 > $0+3 },
            "Card: the top edge does not recede monotonically as the card tips back.")

        // Lambert shading darkens as the card turns away; the sheen band moves toward the hinge.
        var loss: [Double] = []
        for step: Float in [0.3,0.6] {
            u.progress = step; u.shadow = 0
            let bare = try render(renderer,plain,plate,u)
            u.shadow = 1
            let shaded = try render(renderer,plain,plate,u)
            let y = row(CardModel(progress:Double(step)).screenHeight(ofCard:0.15),H)
            loss.append(1-rowMean(shaded,y,(W/2-40)..<(W/2+40))/rowMean(bare,y,(W/2-40)..<(W/2+40)))
        }
        try require(loss[0] > 0.04 && loss[1] > loss[0]+0.08,
            "Card: shading does not darken the card as it turns away (\(loss)).")
        let grey = try fixture(device,width:W,height:H) { _,_ in 128 }
        var sheenRows: [Int] = []
        for step: Float in [0.25,0.5] {
            u.progress = step; u.shadow = 1
            let lit = try render(renderer,grey,plate,u)
            let top = topLit(lit,x:W/2)+H/25
            let profile = (top..<H).map { rowMean(lit,$0,(W/2-40)..<(W/2+40)) }
            let peak = profile.max()!, peakRow = top+profile.firstIndex(of:peak)!
            try require(peak > profile.last!+12 && peak > profile.first!+12,
                "Card: no sheen band brighter than the shaded material at progress \(step).")
            sheenRows.append(peakRow)
        }
        try require(sheenRows[1] > sheenRows[0]+H/10,"Card: the sheen does not sweep toward the hinge.")

        // Intensity changes how far the card has tipped; both frames stay valid cards.
        u.progress = 0.5; u.shadow = 0
        u.intensity = 0
        let lazy = try render(renderer,plain,plate,u)
        u.intensity = 1
        let eager = try render(renderer,plain,plate,u)
        let intensityDifference = meanAbsDiff(lazy,eager)
        try require(intensityDifference >= 6,"Card: intensity 0 and 1 render nearly the same frame.")
        let lazyTop = topLit(lazy,x:W/2), eagerTop = topLit(eager,x:W/2)
        try require(eagerTop > lazyTop+H/10 && lazyTop > 0,"Card: intensity does not change the tilt.")
        for (label,frame) in [("0",lazy),("1",eager)] {
            try require(litCount(frame,row:H-2) >= W-4,"Card: intensity \(label) lost the hinge edge.")
            try require((0..<max(0,topLit(frame,x:W/2)-8)).allSatisfy { rowMean(frame,$0) < 1 },
                "Card: intensity \(label) draws above the card.")
        }
        u.intensity = 0.5

        // One rigid card: the segment count changes nothing.
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        u.segments = 2
        let twoSegments = try render(renderer,checker,plate,u)
        u.segments = 8
        let eightSegments = try render(renderer,checker,plate,u)
        try require(twoSegments.pixels == eightSegments.pixels,"Card: the segment count changed a rigid card.")
        u.segments = 4

        // Softness blurs the card's content without moving its silhouette.
        func halfLevelRow(_ f: Frame) -> Int {
            for y in 0..<H where f.gray(W/2,y) > 100 { return y }
            return H
        }
        u.blur = 0
        let sharpPlain = try render(renderer,plain,plate,u)
        let sharpChecker = try render(renderer,checker,plate,u)
        u.blur = 0.65
        let softPlain = try render(renderer,plain,plate,u)
        let softChecker = try render(renderer,checker,plate,u)
        let silhouetteShift = abs(halfLevelRow(sharpPlain)-halfLevelRow(softPlain))
        try require(silhouetteShift <= 3,"Card: softness moved the top edge by \(silhouetteShift) rows.")
        let midRow = row(model.screenHeight(ofCard:0.5),H)
        try require(abs(litCount(sharpPlain,row:midRow,threshold:100)-litCount(softPlain,row:midRow,threshold:100)) <= 4,
            "Card: softness changed the card's width.")
        let blurRows = (topRow+H/20)..<(topRow+H/5)
        let softnessRatio = variation(softChecker,rows:blurRows)/variation(sharpChecker,rows:blurRows)
        try require(softnessRatio < 0.6,"Card: softness 0.65 did not blur the receding content (\(softnessRatio)).")
        return ["cardTopEdgeRow":topRow,"cardPredictedTopEdgeRow":expectedTop,
                "cardUpperWidth":upperWidth,"cardPredictedUpperWidth":predictedWidth,
                "cardSourceLineRows":lines,"cardPredictedLineRows":predictedLines,"cardLineGaps":gaps,
                "cardHorizontalScale":scaleChecks,"cardTopOfCardByProgress":descent,
                "cardShadingLossAt30And60":loss,"cardSheenPeakRows":sheenRows,
                "cardIntensityDifference":intensityDifference,"cardTopRowByIntensity":[lazyTop,eagerTop],
                "cardSegmentsIgnored":true,"cardSoftnessSilhouetteShift":silhouetteShift,
                "cardSoftnessContrastRatio":softnessRatio]
    }
}
