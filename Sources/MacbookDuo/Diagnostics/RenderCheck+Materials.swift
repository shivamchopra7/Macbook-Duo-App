import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Roll: the sheet below the descending cylinder stays exactly the desktop,
    /// material from above the flat region is wrapped onto the roll, the curved
    /// surface carries an interior highlight, and the roll drops a contact shadow.
    static func checkRoll(_ device: MTLDevice, _ renderer: FoldRenderer,
                          _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = FoldEffect.roll.shaderIndex
        u.blur = 0; u.shadow = 0; u.progress = 0.35
        // A bright band near the top of the image, which only a wrap can bring down.
        let marked = try fixture(device,width:W,height:H) { _,y in
            let height = 1-(Double(y)+0.5)/Double(H)
            return (height >= 0.955 && height <= 0.975) ? 250 : 60
        }
        var markedBytes = [UInt8](repeating:0,count:W*H*4)
        marked.getBytes(&markedBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        let wrapped = try render(renderer,marked,plate,u)
        let flatFrom = row(0.55,H)
        try require(identical(wrapped,markedBytes,rows:flatFrom..<H,columns:0..<W),
            "Roll: the flat sheet below the roll is not the exact desktop.")
        let sourceBand = brightRows(wrapped,above:150,rows:0..<flatFrom)
        try require(sourceBand.count == 1,"Roll: the wrapped band did not appear exactly once on the roll.")
        try require(sourceBand[0] >= row(0.70,H) && sourceBand[0] <= row(0.55,H),
            "Roll: image content from the top edge did not land on the descending roll.")
        try require(topLit(wrapped,x:W/2) >= row(0.80,H),"Roll: content stayed above the roll.")

        let gradient = try fixture(device,width:W,height:H) { _,y in
            let height: Double = 1-(Double(y)+0.5)/Double(H)
            let value: Int = Int(255*height)
            return UInt8(max(0,min(255,value)))
        }
        let ramp = try render(renderer,gradient,plate,u)
        let rollBand = (row(0.72,H)...row(0.60,H)).map { rowMean(ramp,$0) }
        let rollMean = rollBand.reduce(0,+)/Double(rollBand.count)
        let flatTop = rowMean(ramp,row(0.55,H))
        try require(rollMean >= flatTop+30,
            "Roll: the roll does not carry image content from above the flat sheet.")

        u.shadow = 1
        let plain = try fixture(device,width:W,height:H) { _,_ in 128 }
        let lit = try render(renderer,plain,plate,u)
        let band = Array(row(0.727,H)...row(0.585,H))
        let profile = band.map { rowMean(lit,$0) }
        let peak = profile.max()!
        let peakIndex = profile.firstIndex(of:peak)!
        try require(peak > 140,"Roll: the curved highlight is not brighter than the material.")
        try require(peakIndex >= 4 && peakIndex <= profile.count-5,
            "Roll: the highlight sits on the silhouette instead of on the curve.")
        try require(profile.first! < peak*0.85 && profile.last! < peak*0.85,
            "Roll: the roll is not shaded from its top edge to its underside.")
        let contact = [row(0.565,H),row(0.50,H),row(0.30,H)].map { rowMean(lit,$0) }
        try require(contact[0] < 90 && contact[1] > contact[0]+15 && contact[2] > 124,
            "Roll: the roll does not drop a contact shadow that fades away from it.")

        var descent: [Int] = []
        for step: Float in [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8] {
            u.progress = step; u.shadow = 0.65
            descent.append(topLit(try render(renderer,plain,plate,u),x:W/2))
        }
        try require(zip(descent,descent.dropFirst()).allSatisfy { $1 > $0+4 },
            "Roll: the roll does not travel down toward the hinge.")
        return ["rollFlatSheetExactRowsFrom":flatFrom,"rollWrappedBandRow":sourceBand[0],
                "rollHighlightPeak":peak,"rollContactShadowProfile":contact,
                "rollTopOfImageByProgress":descent]
    }

    /// Shutter: four broad panels, each an exact rigid translation of its own band
    /// of desktop pixels, overlapping with lit rims and contact shadows.
    static func checkShutter(_ device: MTLDevice, _ renderer: FoldRenderer,
                             _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let levels = [60,100,140,180]
        let bands = try fixture(device,width:W,height:H) { x,y in
            let up = H-1-y, band = min(3,up*4/H)
            var value = levels[band]
            if up%12 < 6 { value -= 26 }
            if x%24 < 12 { value += 12 }
            if x >= W*30/100 && x < W*36/100 && up >= H*16/100 && up < H*21/100 { value = 250 }
            return UInt8(max(0,min(255,value)))
        }
        var bandBytes = [UInt8](repeating:0,count:W*H*4)
        bands.getBytes(&bandBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        var u = FoldUniforms(); u.effect = FoldEffect.shutter.shaderIndex
        u.blur = 0; u.shadow = 0; u.perspective = 0; u.progress = 0.25
        let telescoped = try render(renderer,bands,plate,u)
        // At a quarter closed each panel has dropped an exact number of rows.
        var slabs: [[String: Int]] = []
        for j in 0..<4 {
            let drop = 39*(j+1)
            let top = Int(0.1875*Double(j+1)*Double(H)), bottom = Int(0.1875*Double(j)*Double(H))
            let rows = (H-top+4)..<(H-bottom-4)
            try require(identical(telescoped,bandBytes,rows:rows,columns:4..<(W-4),shiftedBy:drop),
                "Shutter: panel \(j) is not an exact rigid translation of its own band.")
            slabs.append(["panel":j,"droppedRows":drop,"firstRow":rows.lowerBound,"lastRow":rows.upperBound-1])
        }
        try require((0..<row(0.76,H)).allSatisfy { rowMean(telescoped,$0) < 2 },
            "Shutter: something is still drawn above the retracted stack.")
        // The marker inside the bottom panel keeps its exact size while it drops.
        func markerBox(_ f: Frame) -> (x: Int, y: Int, width: Int, height: Int)? {
            var xs: [Int] = [], ys: [Int] = []
            for y in (H/2)..<H { for x in 0..<W where f.gray(x,y) > 220 { xs.append(x); ys.append(y) } }
            guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return nil }
            return (x0,y0,x1-x0+1,y1-y0+1)
        }
        u.progress = 0
        guard let restBox = markerBox(try render(renderer,bands,plate,u)) else {
            throw AppError.message("Shutter: the rigid-geometry marker is missing when open.")
        }
        var rigid: [[String: Int]] = []
        for step: Float in [0.25,0.5] {
            u.progress = step
            guard let box = markerBox(try render(renderer,bands,plate,u)) else {
                throw AppError.message("Shutter: the marker disappeared from the front panel.")
            }
            try require(abs(box.width-restBox.width) <= 1 && abs(box.height-restBox.height) <= 1 && box.x == restBox.x,
                "Shutter: panel pixels were scaled instead of translated.")
            try require(box.y > restBox.y+8,"Shutter: the front panel did not telescope toward the hinge.")
            rigid.append(["progress":Int(step*100),"x":box.x,"y":box.y,"width":box.width,"height":box.height])
        }
        // Rims and contact shadows at each overlap, on flat mid-grey.
        let plain = try fixture(device,width:W,height:H) { _,_ in 128 }
        u.progress = 0.5; u.shadow = 1; u.blur = 0.4
        let relief = try render(renderer,plain,plate,u)
        var seams: [[String: Double]] = []
        for seam in 1...3 {
            // Measured against each panel's own material, so the rim and the
            // contact shadow are separated from the depth dimming behind the stack.
            let y = H-Int(0.125*Double(seam)*Double(H))
            let rim = rowMean(relief,y+2), front = rowMean(relief,y+14)
            let shade = rowMean(relief,y-4), behind = rowMean(relief,y-14)
            try require(rim >= front+8,"Shutter: the rim of the panel at seam \(seam) is not lit.")
            try require(behind >= shade+12,"Shutter: no contact shadow above the panel at seam \(seam).")
            seams.append(["seamRow":Double(y),"rimMean":rim,"panelMean":front,
                          "shadowMean":shade,"panelBehindMean":behind])
        }
        return ["shutterRigidPanelRows":slabs,"shutterMarkerGeometry":rigid,"shutterSeams":seams]
    }

    /// Flex: one sheet, curved top and side silhouette, a continuous non-affine
    /// squeeze toward the tipped-back top edge, a reflection band and a late collapse.
    static func checkFlex(_ device: MTLDevice, _ renderer: FoldRenderer,
                          _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        var u = FoldUniforms(); u.effect = FoldEffect.flex.shaderIndex
        u.blur = 0; u.shadow = 0; u.progress = 0.5
        let plain = try fixture(device,width:W,height:H) { _,_ in 200 }
        let sheet = try render(renderer,plain,plate,u)
        let middle = topLit(sheet,x:W/2), left = topLit(sheet,x:W/10), right = topLit(sheet,x:W*9/10)
        try require(left > middle+5 && right > middle+5,"Flex: the top silhouette is not curved.")
        let high = litCount(sheet,row:row(0.70,H)), low = litCount(sheet,row:row(0.10,H))
        try require(Double(high) < Double(low)*0.97,"Flex: the side silhouette does not draw in toward the top.")

        // Marker lines from the source must crowd together toward the top edge.
        let ruled = try fixture(device,width:W,height:H) { _,y in
            let height = 1-(Double(y)+0.5)/Double(H)
            for line in [0.25,0.5,0.75] where abs(height-line) < 0.004 { return 240 }
            return 40
        }
        let deformed = try render(renderer,ruled,plate,u)
        // Sampled down the centre line: the dome silhouette curves the interior
        // rows as well, which is the point of the effect.
        let lines = brightRows(deformed,above:130,rows:0..<H,columns:(W/2-40)..<(W/2+40))
        try require(lines.count == 3,"Flex: expected three continuous source lines, measured \(lines).")
        let gaps = [H-1-lines[2],lines[2]-lines[1],lines[1]-lines[0]]
        try require(gaps[0] > gaps[1]+8 && gaps[1] > gaps[2]+8,
            "Flex: the vertical deformation is not a continuous squeeze toward the top.")

        u.shadow = 1
        let shaded = try render(renderer,plain,plate,u)
        let profileRow = row(0.36,H)
        let lit = (0..<W).filter { shaded.gray($0,profileRow) > 24 }
        let peakX = lit.max { shaded.gray($0,profileRow) < shaded.gray($1,profileRow) }!
        try require(peakX < W*35/100,"Flex: the reflection band is not placed by the surface normal.")
        try require(shaded.gray(peakX,profileRow) >= shaded.gray(W*85/100,profileRow)+8,
            "Flex: no reflection or depth shading across the bow.")

        u.shadow = 0.65; u.progress = 0.75
        let early = H-topLit(try render(renderer,plain,plate,u),x:W/2)
        u.progress = 0.95
        let late = H-topLit(try render(renderer,plain,plate,u),x:W/2)
        try require(Double(late) < Double(early)*0.4,"Flex: the sheet does not collapse toward the hinge.")
        var hingeLoss: [Double] = []
        for progress: Float in [0.05,0.10] {
            u.progress = progress; u.shadow = 0
            let unshaded = try render(renderer,plain,plate,u)
            u.shadow = 1
            let contact = try render(renderer,plain,plate,u)
            let sampleRow = row(0.02,H), columns = (W/2-20)..<(W/2+20)
            hingeLoss.append(1-rowMean(contact,sampleRow,columns)/rowMean(unshaded,sampleRow,columns))
        }
        try require(hingeLoss[0] < 0.12 && hingeLoss[0] < hingeLoss[1]*0.8,
            "Flex: the early hinge shadow arrived at full strength.")
        return ["flexTopSilhouetteRows":["centre":middle,"left":left,"right":right],
                "flexLitWidthTopVersusHinge":[high,low],"flexSourceLineRows":lines,"flexLineGaps":gaps,
                "flexReflectionPeakColumn":peakX,"flexLitHeightAt75And95":[early,late],
                "flexEarlyHingeShadowLoss":hingeLoss]
    }

    /// Iris: the desktop stays exactly where it is inside the aperture, dark blades
    /// overlap with seams and contact shadows, the aperture sits above the hinge,
    /// it closes monotonically, and the blades themselves go black at closure.
    static func checkIris(_ device: MTLDevice, _ renderer: FoldRenderer,
                         _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var checkerBytes = [UInt8](repeating:0,count:W*H*4)
        checker.getBytes(&checkerBytes,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        var u = FoldUniforms(); u.effect = FoldEffect.iris.shaderIndex
        u.blur = 0; u.shadow = 0; u.progress = 0.35
        let closing = try render(renderer,checker,plate,u)
        let aspect = Double(W)/Double(H)
        let columns = Int(0.227*Double(W)), centreX = W/2, centreRow = row(0.14,H)
        let box = (x: centreX-columns, y: max(0,centreRow-Int(0.35*Double(H))))
        try require(identical(closing,checkerBytes,rows:box.y..<H,columns:box.x..<(centreX+columns)),
            "Iris: the desktop inside the aperture moved or was reshaded.")

        let white = try fixture(device,width:W,height:H) { _,_ in 255 }
        u.shadow = 1; u.blur = 0.3; u.progress = 0.55
        let blades = try render(renderer,white,plate,u)
        let corner = (0..<(H/6)).flatMap { y in (0..<(W/6)).map { blades.gray($0,y) } }
        try require(Double(corner.reduce(0,+))/Double(corner.count) < 60,
            "Iris: the blades are not dark, precision blades.")
        // Seams around the closed part of the aperture, and the polygon's own facets.
        var arc: [Int] = []
        for degrees in stride(from:-14,through:194,by:1) {
            guard let point = irisPoint(0.56,Double(degrees)*Double.pi/180,blades) else { continue }
            arc.append(blades.gray(point.0,point.1))
        }
        let seams = zip(arc,arc.dropFirst()).reduce(0) { $0+(abs($1.0-$1.1) > 3 ? 1 : 0) }
        try require(seams >= 3,"Iris: the blades do not overlap with visible seams.")
        var boundary: [Double] = []
        for degrees in stride(from:20,through:160,by:2) {
            let angle = Double(degrees)*Double.pi/180
            var edge = 1.2
            for step in stride(from:0.06,through:1.2,by:0.004) {
                guard let point = irisPoint(step,angle,blades) else { break }
                if blades.gray(point.0,point.1) < 100 { edge = step; break }
            }
            boundary.append(edge)
        }
        let facets = (1..<(boundary.count-1)).reduce(0) {
            $0+((boundary[$1] < boundary[$1-1] && boundary[$1] <= boundary[$1+1]) ? 1 : 0)
        }
        try require(facets >= 2,"Iris: the aperture is not bounded by straight blade edges.")

        func facetAngle(_ progress: Float) throws -> Double {
            var v = FoldUniforms(); v.effect = FoldEffect.iris.shaderIndex
            v.blur = 0; v.shadow = 1; v.progress = progress
            let frame = try render(renderer,white,plate,v)
            var best = (angle: 0.0, radius: 9.9)
            for degrees in stride(from:70,through:130,by:1) {
                let angle = Double(degrees)*Double.pi/180
                for step in stride(from:0.04,through:1.2,by:0.002) {
                    guard let point = irisPoint(step,angle,frame) else { break }
                    if frame.gray(point.0,point.1) < 100 {
                        if step < best.radius { best = (Double(degrees),step) }
                        break
                    }
                }
            }
            return best.angle
        }
        let early = try facetAngle(0.4), later = try facetAngle(0.8)
        let twist = later-early
        try require(twist >= 3 && twist <= 12,"Iris: the blades do not twist as they close.")

        var closingCounts: [Int] = []
        for step: Float in [0.2,0.35,0.5,0.65,0.8] {
            u.progress = step
            closingCounts.append(brightCount(try render(renderer,white,plate,u),128))
        }
        try require(zip(closingCounts,closingCounts.dropFirst()).allSatisfy { $1 < $0 },
            "Iris: the aperture does not close monotonically.")
        u.progress = 0.7
        let placed = try render(renderer,white,plate,u)
        let centroid = brightCentroid(placed,128)
        try require(centroid.count > 0 && centroid.y > Double(H)*0.72 && abs(centroid.x-Double(W)/2) < Double(W)*0.03,
            "Iris: the aperture is not centred just above the hinge.")
        u.progress = 0.98
        let shut = try render(renderer,white,plate,u)
        var bladeMax = 0
        for y in 0..<H { for x in 0..<W {
            let dx = (Double(x)/Double(W)-0.5)*aspect, dy = 1-(Double(y)+0.5)/Double(H)-0.14
            if (dx*dx+dy*dy).squareRoot() > 0.06 { bladeMax = max(bladeMax,shut.gray(x,y)) }
        } }
        try require(bladeMax <= 12,"Iris: the blades are still visible at complete closure.")
        try require(brightCount(shut,100) < W*H/1500,"Iris: too much of the desktop survives at closure.")
        // Hold blade geometry fixed so only optical defocus can change the
        // checker contrast in a narrow band just inside the right-hand rim.
        u.progress = 0.5; u.shadow = 0; u.blur = 0.65; u.defocus = 0
        let apertureMask = try render(renderer,white,plate,u)
        var rimSamples: [(Int,Int)] = []
        for y in 0..<H {
            guard let edge = (W/2..<W-40).last(where:{ apertureMask.gray($0,y) >= 250 }),
                  apertureMask.gray(W-40,y) < 250, edge > W/2+40 else { continue }
            for x in (edge-30)..<(edge-5) { rimSamples.append((x,y)) }
        }
        try require(rimSamples.count > 100,"Iris: no interior rim samples for the blur check.")
        var rimContrast: [Double] = []
        for defocus: Float in [0.16,0.4,0.8] {
            u.defocus = defocus
            let frame = try render(renderer,checker,plate,u)
            rimContrast.append(Double(rimSamples.reduce(0) { $0+abs(frame.gray($1.0+1,$1.1)-frame.gray($1.0,$1.1)) })/Double(rimSamples.count))
        }
        try require(rimContrast[0] > rimContrast[1]+0.25 && rimContrast[1] > rimContrast[2]+0.25,
            "Iris: rim blur stopped progressing after the early defocus range.")
        return ["irisFixedDesktopBox":["x":box.x,"y":box.y,"width":columns*2,"height":H-box.y],
                "irisSeamSteps":seams,"irisApertureFacets":facets,"irisTwistDegrees":twist,
                "irisApertureAreaByProgress":closingCounts,
                "irisApertureCentroid":["x":centroid.x,"y":centroid.y],
                "irisBladeMaximumAtClosure":bladeMax,"irisProgressiveRimContrast":rimContrast]
    }
}
