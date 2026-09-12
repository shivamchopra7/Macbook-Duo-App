import AppKit
import MetalKit
import CoreVideo
import FoldCore

extension RenderCheck {
    /// Ghost must anchor content in the resting plane, add blur progressively,
    /// and continue showing fresh content. No desktop capture is used here.
    static func checkGhost(_ device: MTLDevice, _ renderer: FoldRenderer,
                           _ plate: MTLTexture, _ W: Int, _ H: Int) throws -> [String: Any] {
        let checker = try fixture(device,width:W,height:H) { x,y in ((x/10+y/10)%2 == 0) ? 40 : 240 }
        var source = [UInt8](repeating:0,count:W*H*4)
        checker.getBytes(&source,bytesPerRow:W*4,from:MTLRegionMake2D(0,0,W,H),mipmapLevel:0)
        var u = FoldUniforms(); u.effect = FoldEffect.ghost.shaderIndex
        u.blur = 0; u.shadow = 0
        let horizontal = try fixture(device,width:W,height:H) { x,_ in UInt8(Double(x)*255/Double(W-1)) }
        let vertical = try fixture(device,width:W,height:H) { _,y in UInt8(Double(y)*255/Double(H-1)) }
        var anchorChecks = 0
        for reference: Double in [45,90,105,128,140] {
            for degrees: Double in [2,5,15,30,45,60] {
                for perspective: Double in [0,0.27165042,0.7,1] {
                    let angle = degrees * .pi/180
                    let state = FoldVisualState.at(angle:reference-degrees,reference:reference)
                    guard state.progress < 0.86 else { continue } // Deep-close fading has its own check.
                    u.progress = Float(state.progress);u.tilt = Float(state.tilt)
                    u.referenceAngle = Float(state.referenceAngle);u.perspective = Float(perspective)
                    let horizontalFrame = try render(renderer,horizontal,plate,u)
                    let verticalFrame = try render(renderer,vertical,plate,u)
                    // Independent world-space ray/plane intersection. The viewer
                    // stays fixed over the keyboard as the resting angle changes.
                    let rest = max(90,reference) * .pi/180, current = rest-angle
                    let eyeHeight = 1.6, eyeDepth = 2.6-perspective
                    let normalEye = -cos(current)*eyeHeight+sin(current)*eyeDepth
                    guard normalEye > 0.05 else { continue } // The panel faces away from this viewer.
                    for sourceX: Double in [0.25,0.5,0.75] {
                        for sourceY: Double in [0.35,0.65,0.9] {
                            let h = 1-sourceY
                            let worldY = h*sin(rest), worldZ = h*cos(rest)
                            let normalPoint = -cos(current)*worldY+sin(current)*worldZ
                            let t = normalEye/(normalEye-normalPoint)
                            let hitY = eyeHeight+t*(worldY-eyeHeight)
                            let hitZ = eyeDepth+t*(worldZ-eyeDepth)
                            let panelX = 0.5+(sourceX-0.5)*t
                            let panelY = 1-(hitY*sin(current)+hitZ*cos(current))
                            guard panelX > 0.05 && panelX < 0.95 && panelY > 0.05 && panelY < 0.95 else { continue }
                            let x = Int(panelX*Double(W)), y = Int(panelY*Double(H))
                            try require(abs(Double(horizontalFrame.gray(x,y))/255-sourceX) < 0.009,
                                "Ghost: horizontal content failed to stay anchored over the keyboard.")
                            try require(abs(Double(verticalFrame.gray(x,y))/255-sourceY) < 0.009,
                                "Ghost: the desktop followed the lid instead of keeping its resting plane.")
                            anchorChecks += 1
                        }
                    }
                }
            }
        }
        try require(anchorChecks >= 500,"Ghost: too few visible world-space anchor points were checked.")
        // Isolate optical onset from checker resampling; geometry is proven above.
        u.tilt = 0

        let topRows = (H/8)..<(H/3), bottomRows = (H*3/4)..<(H*7/8)
        u.progress = 0
        let open = try render(renderer,checker,plate,u)
        let sharpContrast = variation(open,rows:topRows)
        var onset: [[String:Any]] = []
        for reference: Double in [45,90,128] {
            var previousRatio = 1.0
            for delta: Double in [0,1,2,3,5,8,10,15,25,35] {
                let state = FoldVisualState.at(angle:reference-delta,reference:reference)
                u.progress = Float(state.progress); u.defocus = Float(state.defocus)
                u.perspective = 0.7; u.blur = 0.65
                let frame = try render(renderer,checker,plate,u)
                let ratio = variation(frame,rows:topRows)/sharpContrast
                if delta <= 3 { try require(ratio > 0.98,"Ghost: a tiny bend blurred too abruptly.") }
                if delta == 5 { try require(ratio > 0.90,"Ghost: the first five degrees should remain mostly sharp.") }
                if delta == 15 { try require(ratio < 0.90 && ratio > 0.60,"Ghost: fifteen degrees should soften content while preserving its structure.") }
                try require(ratio <= previousRatio+0.005,"Ghost: blur did not build progressively with the angle.")
                previousRatio = ratio
                onset.append(["referenceAngle":reference,"delta":delta,"contrastRatio":ratio])
            }
        }

        // The dock and other hinge-adjacent content retain their structure
        // instead of disappearing into the same blur as the far edge.
        u.progress = 0.5; u.defocus = 0.6
        let hingeRows = (H*9/10)..<(H*19/20)
        let hingeFrame = try render(renderer,checker,plate,u)
        let hingeReadability = variation(hingeFrame,rows:hingeRows)/variation(open,rows:hingeRows)
        try require(hingeReadability > 0.94,"Ghost: deep defocus spread too strongly into the hinge area.")

        // Test geometry and optics together through every physical degree.
        // The coarse sweep above isolates blur; this catches combined resampling steps.
        var previousContrast = 1.0, largestContrastStep = 0.0
        for delta in 0...25 {
            let state = FoldVisualState.at(angle:90-Double(delta),reference:90)
            u.progress = Float(state.progress); u.defocus = Float(state.defocus); u.tilt = Float(state.tilt); u.referenceAngle = Float(state.referenceAngle)
            let frame = try render(renderer,checker,plate,u)
            let contrast = variation(frame,rows:topRows)/sharpContrast
            largestContrastStep = max(largestContrastStep,abs(contrast-previousContrast))
            previousContrast = contrast
        }
        try require(largestContrastStep < 0.10,"Ghost: a one-degree movement caused a sudden blur step.")
        let defocused = try render(renderer,checker,plate,u)
        let topRatio = variation(defocused,rows:topRows)/sharpContrast
        let bottomRatio = variation(defocused,rows:bottomRows)/variation(open,rows:bottomRows)
        try require(topRatio < bottomRatio*0.85,"Ghost: focus should fall away more at the top than at the hinge.")

        let white = try fixture(device,width:W,height:H) { _,_ in 255 }
        let black = try fixture(device,width:W,height:H) { _,_ in 0 }
        let first = try render(renderer,white,plate,u,revision:5200)
        let next = try render(renderer,black,plate,u,revision:5201)
        try require(first.gray(W/2,H/2) == 255 && next.gray(W/2,H/2) == 0,
            "Ghost: the fixed desktop froze an earlier frame or unexpectedly dimmed.")
        return ["ghostRestingPlaneProjectionChecks":anchorChecks,
                "ghostGradualOnset":onset,"ghostLargestContrastStepPerDegree":largestContrastStep,
                "ghostTopContrastRatio":topRatio,"ghostHingeContrastRatio":bottomRatio,
                "ghostPhysicalTiltSweep":true,"ghostContentStaysLive":true,
                "ghostDeepDefocusHingeReadability":hingeReadability]
    }
}
