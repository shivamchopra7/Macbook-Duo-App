import SwiftUI

/// A padded glass slab that hosts a group of controls.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = GlassPalette.cardPadding
    var cornerRadius: CGFloat = GlassPalette.cornerRadius
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .glassSurface(cornerRadius:cornerRadius)
    }
}

/// A small glass capsule for status readouts such as the lid angle.
struct GlassPill<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal,12).padding(.vertical,7)
            .glassSurface(cornerRadius:GlassPalette.pillRadius,tint:tint,shadowed:false)
    }
}

/// A small caption in the contrast-checked secondary tone.
struct GlassCaption: View {
    let text: String
    var size: CGFloat = 11
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(text)
            .font(.system(size:size))
            .foregroundStyle(GlassPalette.secondaryText(scheme))
            .fixedSize(horizontal:false,vertical:true)
    }
}
