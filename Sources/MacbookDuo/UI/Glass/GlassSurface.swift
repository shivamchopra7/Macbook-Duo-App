import SwiftUI

/// The one place a Liquid Glass surface is drawn. macOS 26 uses the system
/// material; earlier systems get a translucent stand-in with a specular rim,
/// an inner top highlight and a soft drop shadow.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = GlassPalette.cornerRadius
    var tint: Color? = nil
    var interactive = false
    var shadowed = true

    func body(content: Content) -> some View {
        if #available(macOS 26,*) {
            content.modifier(SystemGlass(cornerRadius:cornerRadius,tint:tint,interactive:interactive))
        } else {
            content.modifier(FallbackGlass(cornerRadius:cornerRadius,tint:tint,shadowed:shadowed))
        }
    }
}

@available(macOS 26,*)
private struct SystemGlass: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    func body(content: Content) -> some View {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return content.glassEffect(glass,in:RoundedRectangle(cornerRadius:cornerRadius,style:.continuous))
    }
}

private struct FallbackGlass: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let shadowed: Bool
    @Environment(\.colorScheme) private var scheme
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius:cornerRadius,style:.continuous) }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(tint.map { $0.opacity(0.35) } ?? GlassPalette.glassFill(scheme))
                    // Inner top highlight: light catches the upper edge of the slab.
                    shape.fill(LinearGradient(colors:[Color.white.opacity(scheme == .dark ? 0.16 : 0.5),.clear],
                                              startPoint:.top,endPoint:.center))
                }
            }
            .overlay(shape.strokeBorder(GlassPalette.rim(scheme),lineWidth:1))
            .clipShape(shape)
            .shadow(color:shadowed ? GlassPalette.shadow(scheme) : .clear,radius:shadowed ? 14 : 0,x:0,y:shadowed ? 6 : 0)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = GlassPalette.cornerRadius, tint: Color? = nil,
                      interactive: Bool = false, shadowed: Bool = true) -> some View {
        modifier(GlassSurface(cornerRadius:cornerRadius,tint:tint,interactive:interactive,shadowed:shadowed))
    }
}
