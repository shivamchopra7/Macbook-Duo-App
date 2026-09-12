import SwiftUI
import AppKit

/// The layered brand gradient behind every glass surface. It drifts slowly
/// while the window is on screen and freezes when the window is occluded or
/// Reduce Motion is on, so an idle settings window costs nothing.
struct GlassBackdrop: View {
    let reducedMotion: Bool
    @State private var windowVisible = true
    @Environment(\.colorScheme) private var scheme

    private static let period: TimeInterval = 18

    var body: some View {
        TimelineView(.animation(minimumInterval:1/24,paused:reducedMotion || !windowVisible)) { context in
            let phase = reducedMotion ? 0.35 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy:Self.period)/Self.period
            ZStack {
                GlassPalette.ground(scheme)
                if #available(macOS 15,*) {
                    MeshBackdrop(phase:phase,scheme:scheme)
                } else {
                    LayeredBackdrop(phase:phase,scheme:scheme)
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for:NSWindow.didChangeOcclusionStateNotification)) { note in
            guard let window = note.object as? NSWindow, window.title == "Macbook Duo" else { return }
            windowVisible = window.occlusionState.contains(.visible)
        }
        .accessibilityHidden(true)
    }
}

private func drift(_ phase: Double, _ offset: Double, amplitude: Double) -> Float {
    Float(sin((phase+offset) * 2 * .pi) * amplitude)
}

@available(macOS 15,*)
private struct MeshBackdrop: View {
    let phase: Double
    let scheme: ColorScheme

    var body: some View {
        let dark = scheme == .dark
        let ground = GlassPalette.ground(scheme)
        let blue = GlassPalette.electricBlue.opacity(dark ? 0.55 : 0.30)
        let indigo = GlassPalette.indigo.opacity(dark ? 0.55 : 0.26)
        let cyan = GlassPalette.cyan.opacity(dark ? 0.42 : 0.30)
        let mid = dark ? Color(red:0.09,green:0.11,blue:0.19) : Color(red:0.90,green:0.93,blue:1.0)
        MeshGradient(width:3,height:3,points:[
            [0,0],[0.5+drift(phase,0.10,amplitude:0.12),0],[1,0],
            [0,0.5+drift(phase,0.35,amplitude:0.10)],[0.5+drift(phase,0.60,amplitude:0.16),0.5+drift(phase,0.85,amplitude:0.14)],[1,0.5+drift(phase,0.20,amplitude:0.10)],
            [0,1],[0.5+drift(phase,0.45,amplitude:0.12),1],[1,1]
        ],colors:[
            indigo,ground,cyan,
            ground,mid,ground,
            blue,ground,indigo
        ])
        .blur(radius:dark ? 20 : 30)
    }
}

/// macOS 13–14 fallback: the same palette stacked as soft radial pools.
private struct LayeredBackdrop: View {
    let phase: Double
    let scheme: ColorScheme

    var body: some View {
        let dark = scheme == .dark
        let alpha = dark ? 0.5 : 0.28
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                LinearGradient(colors:[GlassPalette.ground(scheme),
                                       dark ? Color(red:0.08,green:0.10,blue:0.18) : Color(red:0.92,green:0.94,blue:1.0)],
                               startPoint:.top,endPoint:.bottom)
                pool(GlassPalette.indigo.opacity(alpha),at:CGPoint(x:size.width*(0.15+Double(drift(phase,0.1,amplitude:0.08))),y:size.height*0.1),radius:size.width*0.5)
                pool(GlassPalette.cyan.opacity(alpha*0.8),at:CGPoint(x:size.width*(0.9+Double(drift(phase,0.4,amplitude:0.06))),y:size.height*(0.2+Double(drift(phase,0.7,amplitude:0.1)))),radius:size.width*0.45)
                pool(GlassPalette.electricBlue.opacity(alpha),at:CGPoint(x:size.width*(0.3+Double(drift(phase,0.6,amplitude:0.1))),y:size.height*1.0),radius:size.width*0.55)
            }
        }
    }

    private func pool(_ color: Color, at center: CGPoint, radius: CGFloat) -> some View {
        RadialGradient(colors:[color,.clear],center:.center,startRadius:0,endRadius:radius)
            .frame(width:radius*2,height:radius*2)
            .position(center)
    }
}
