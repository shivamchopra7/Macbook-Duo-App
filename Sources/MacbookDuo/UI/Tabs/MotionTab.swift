import SwiftUI
import FoldCore

/// How the effect follows the lid: source, thresholds, stillness, the
/// progress curve and its timing. Reset restores every option.
struct MotionTab: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private var previewAngle: Binding<Double> {
        Binding(get:{ model.followLid ? model.lidAngle ?? model.clearAngle : model.previewAngle },
                set:{ model.previewAngle = $0 })
    }
    private var previewAngleText: String {
        if model.followLid { return model.lidAngle.map { String(format:"%.0f°",$0) } ?? "—" }
        return String(format:"%.0f°",model.previewAngle)
    }

    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:10) {
                GlassToggleRow(label:L10n.text("Follow my lid"),isOn:$model.followLid)
                Spacer()
                Text(model.previewPlaying ? L10n.text("Replaying") : (model.followLid ? L10n.text("Live preview") : L10n.text("Manual preview")))
                    .font(.system(size:10.5,weight:.medium)).foregroundStyle(GlassPalette.secondaryText(scheme))
            }
            GlassSliderRow(label:L10n.text("Preview angle"),value:previewAngle,range:5...140,text:previewAngleText)
                .disabled(model.followLid || model.previewPlaying)
            GlassSliderRow(label:L10n.text("Clears at"),value:$model.clearAngle,range:60...140,text:String(format:"%.0f°",model.clearAngle))
            divider
            GlassToggleRow(label:L10n.text("Clear when the lid is still"),isOn:$model.clearWhenStill)
            GlassSliderRow(label:L10n.text("Clear after"),value:$model.stillnessDelay,range:1...5,
                           text:L10n.format("%.0f s",model.stillnessDelay),step:1)
                .disabled(!model.clearWhenStill)
            GlassCaption(text:L10n.text("Move the lid to bring back the effect."),size:10.5)
            divider
            HStack(alignment:.firstTextBaseline,spacing:10) {
                Text(L10n.text("Curve")).font(.system(size:11.5,weight:.medium)).frame(width:92,alignment:.leading)
                Text(L10n.text(model.curve.summary))
                    .font(.system(size:10.5)).foregroundStyle(GlassPalette.secondaryText(scheme))
                    .lineLimit(1).frame(maxWidth:.infinity,alignment:.trailing)
            }
            GlassSegmentedPicker(label:L10n.text("Curve"),segments:FoldCurve.allCases.map { curve in
                .init(option:curve,title:L10n.text(curve.title),symbol:curve.symbol,
                      help:L10n.format("Curve: %@ — %@",L10n.text(curve.title),L10n.text(curve.summary)))
            },selection:$model.curve)
            .help(L10n.format("Curve: %@ — %@",L10n.text(model.curve.title),L10n.text(model.curve.summary)))
            GlassSliderRow(label:L10n.text("Response"),value:$model.responseTime,range:EffectOptions.responseRange,
                           text:L10n.format("%.0f ms",model.responseTime*1000))
            GlassSliderRow(label:L10n.text("Clear duration"),value:$model.clearDuration,range:EffectOptions.clearRange,
                           text:L10n.format("%.1f s",model.clearDuration))
            HStack {
                Spacer()
                Button(L10n.text("Reset to defaults")) { withAnimation(GlassPalette.transition) { model.resetOptions() } }
                    .buttonStyle(.glassQuiet)
                    .accessibilityLabel(L10n.text("Reset to defaults"))
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(scheme == .dark ? 0.12 : 0.08)).frame(height:1).padding(.vertical,1)
    }
}
