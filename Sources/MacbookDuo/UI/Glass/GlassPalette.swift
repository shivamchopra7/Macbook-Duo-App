import SwiftUI

/// Brand colors and the contrast-checked text tones used on every glass surface.
/// Text is never left to the material's default: secondary text sits at
/// ≥ 4.5:1 against the airy light ground and the deep slate dark ground.
enum GlassPalette {
    static let electricBlue = Color(red:0.184,green:0.420,blue:1.0)   // #2F6BFF
    static let indigo = Color(red:0.357,green:0.294,blue:1.0)         // #5B4BFF
    static let cyan = Color(red:0.216,green:0.784,blue:0.961)         // #37C8F5

    static let cornerRadius: CGFloat = 16
    static let pillRadius: CGFloat = 999
    static let cardPadding: CGFloat = 14

    static let accent = electricBlue

    /// Accent used for text and glyphs. Deeper in light mode so it reads
    /// on the off-white ground; brighter in dark mode for the same reason.
    static func accentText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red:0.498,green:0.651,blue:1.0) : Color(red:0.118,green:0.310,blue:0.847)
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.66)
    }

    static func ground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red:0.055,green:0.070,blue:0.110) : Color(red:0.955,green:0.965,blue:0.985)
    }

    /// The material tint used by the pre-macOS 26 glass fallback.
    static func glassFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.42)
    }

    static func rim(_ scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors:[Color.white.opacity(scheme == .dark ? 0.55 : 0.9),
                               Color.white.opacity(scheme == .dark ? 0.05 : 0.25)],
                       startPoint:.topLeading,endPoint:.bottomTrailing)
    }

    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.45) : Color(red:0.25,green:0.32,blue:0.55).opacity(0.16)
    }

    /// The window-wide animation: `.smooth` where available, an ease elsewhere.
    static var transition: Animation {
        if #available(macOS 14,*) { return .smooth(duration:0.35) }
        return .easeInOut(duration:0.35)
    }

    static var press: Animation {
        if #available(macOS 14,*) { return .snappy(duration:0.22) }
        return .spring(response:0.25,dampingFraction:0.7)
    }
}
