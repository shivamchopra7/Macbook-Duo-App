import SwiftUI
import FoldCore

/// Twelve tiles, the selected effect's summary, and its options.
struct EffectsTab: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    private let columns = Array(repeating:GridItem(.flexible(),spacing:8),count:4)

    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            LazyVGrid(columns:columns,spacing:8) {
                ForEach(FoldEffect.allCases) { effect in
                    EffectTile(effect:effect,selected:model.effect == effect) {
                        withAnimation(GlassPalette.transition) { model.effect = effect }
                    }
                }
            }
            .accessibilityElement(children:.contain)
            .accessibilityLabel(L10n.text("Effect"))
            HStack(alignment:.top,spacing:6) {
                Image(systemName:model.effect.symbol)
                    .font(.system(size:11,weight:.semibold))
                    .foregroundStyle(GlassPalette.accentText(scheme))
                    .frame(width:14)
                    .accessibilityHidden(true)
                Text(L10n.text(model.effect.summary))
                    .font(.system(size:11.5))
                    .foregroundStyle(GlassPalette.secondaryText(scheme))
                    .lineLimit(2).fixedSize(horizontal:false,vertical:true)
            }
            .frame(height:30,alignment:.top)
            .help(L10n.format("Effect: %@ — %@",L10n.text(model.effect.title),L10n.text(model.effect.summary)))
            .id(model.effect)
            .transition(.opacity)
            GlassSliderRow(label:L10n.text("Intensity"),value:$model.intensity,range:EffectOptions.intensityRange,
                           text:String(format:"%.0f%%",model.intensity*100))
            if model.effect.usesSegments {
                GlassStepperRow(label:L10n.text("Segments"),value:$model.segments,range:EffectOptions.segmentRange)
                    .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        .animation(GlassPalette.transition,value:model.effect.usesSegments)
    }
}

/// One selectable effect. A Button, so it takes keyboard focus and reads its
/// title to VoiceOver; the tooltip carries the summary.
private struct EffectTile: View {
    let effect: FoldEffect
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action:action) {
            VStack(spacing:6) {
                Image(systemName:effect.symbol)
                    .font(.system(size:16,weight:.medium))
                    .foregroundStyle(selected ? Color.white : GlassPalette.accentText(scheme))
                    .frame(height:20)
                Text(L10n.text(effect.title))
                    .font(.system(size:11,weight:.semibold))
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            .frame(maxWidth:.infinity).frame(height:58)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius:11,style:.continuous)
                        .fill(LinearGradient(colors:[GlassPalette.electricBlue,GlassPalette.indigo],
                                             startPoint:.topLeading,endPoint:.bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius:11,style:.continuous).strokeBorder(Color.white.opacity(0.4),lineWidth:1))
                        .shadow(color:GlassPalette.electricBlue.opacity(0.45),radius:8,y:3)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius:11,style:.continuous))
            .contentShape(.focusEffect,RoundedRectangle(cornerRadius:11,style:.continuous))
        }
        .buttonStyle(TileButtonStyle(selected:selected))
        .accessibilityLabel(L10n.text(effect.title))
        .accessibilityHint(L10n.text(effect.summary))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .help(L10n.text(effect.summary))
    }
}

private struct TileButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(TileGlass(active:!selected))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(GlassPalette.press,value:configuration.isPressed)
    }
}

/// Unselected tiles use a flat translucent slab: twelve live glass lenses
/// over the backdrop were the most expensive part of the window.
private struct TileGlass: ViewModifier {
    let active: Bool
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        if active {
            let shape = RoundedRectangle(cornerRadius:11,style:.continuous)
            content
                .background(shape.fill(GlassPalette.glassFill(scheme)))
                .overlay(shape.strokeBorder(Color.white.opacity(scheme == .dark ? 0.10 : 0.55),lineWidth:1))
        } else { content }
    }
}
