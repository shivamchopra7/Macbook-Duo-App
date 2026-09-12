import SwiftUI

/// Buttons on glass. `.prominent` is the tinted call to action; `.quiet`
/// is a clear glass pill. Both shrink to 0.97 with a spring while pressed.
struct GlassButtonStyle: ButtonStyle {
    enum Variant { case prominent, quiet }
    var variant: Variant = .quiet
    var cornerRadius: CGFloat = 10
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 6
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius:cornerRadius,style:.continuous)
        configuration.label
            .font(.system(size:12,weight:variant == .prominent ? .semibold : .medium))
            .foregroundStyle(variant == .prominent ? Color.white : Color.primary)
            .padding(.horizontal,horizontalPadding).padding(.vertical,verticalPadding)
            .background {
                if variant == .prominent {
                    shape.fill(LinearGradient(colors:[GlassPalette.electricBlue,GlassPalette.indigo],
                                              startPoint:.topLeading,endPoint:.bottomTrailing))
                    shape.fill(LinearGradient(colors:[Color.white.opacity(0.28),.clear],startPoint:.top,endPoint:.center))
                    shape.strokeBorder(Color.white.opacity(0.35),lineWidth:1)
                }
            }
            .modifier(QuietGlass(active:variant == .quiet,cornerRadius:cornerRadius))
            .contentShape(shape)
            .contentShape(.focusEffect,shape)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? (scheme == .dark ? 0.08 : -0.04) : 0)
            .animation(GlassPalette.press,value:configuration.isPressed)
    }
}

private struct QuietGlass: ViewModifier {
    let active: Bool
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        if active { content.glassSurface(cornerRadius:cornerRadius,interactive:true,shadowed:false) }
        else { content }
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glassProminent: GlassButtonStyle { GlassButtonStyle(variant:.prominent) }
    static var glassQuiet: GlassButtonStyle { GlassButtonStyle(variant:.quiet) }
}

/// A round glass button holding one SF Symbol, used in the header.
struct GlassIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action:action) {
            Image(systemName:symbol)
                .font(.system(size:13,weight:.semibold))
                .foregroundStyle(GlassPalette.accentText(scheme))
                .frame(width:16,height:16)
        }
        .buttonStyle(GlassButtonStyle(variant:.quiet,cornerRadius:GlassPalette.pillRadius,horizontalPadding:8,verticalPadding:8))
        .accessibilityLabel(label).help(label)
    }
}
