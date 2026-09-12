import SwiftUI

/// Label, slider and a monospaced readout on one line. The label width is
/// shared across a card so the sliders line up.
struct GlassSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let text: String
    var step: Double? = nil
    var labelWidth: CGFloat = 92
    var valueWidth: CGFloat = 44
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing:10) {
            Text(label)
                .font(.system(size:11.5,weight:.medium))
                .frame(width:labelWidth,alignment:.leading)
                .lineLimit(1).minimumScaleFactor(0.8)
            Group {
                if let step { Slider(value:$value,in:range,step:step) }
                else { Slider(value:$value,in:range) }
            }
            .controlSize(.small)
            .tint(GlassPalette.accent)
            .accessibilityLabel(label)
            Text(text)
                .font(.system(size:11.5,weight:.medium,design:.monospaced))
                .foregroundStyle(GlassPalette.secondaryText(scheme))
                .frame(width:valueWidth,alignment:.trailing)
                .lineLimit(1)
        }
        .opacity(isEnabled ? 1 : 0.55)
    }
}

/// A switch with its title in the row's label column.
struct GlassToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var help: String? = nil

    var body: some View {
        Toggle(isOn:$isOn) {
            Text(label).font(.system(size:11.5,weight:.medium))
        }
        .toggleStyle(.switch).controlSize(.small)
        .tint(GlassPalette.accent)
        .accessibilityLabel(label)
        .help(help ?? label)
    }
}

/// Integer stepper with a slider, used for the segment count.
struct GlassStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var labelWidth: CGFloat = 92
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing:10) {
            Text(label).font(.system(size:11.5,weight:.medium)).frame(width:labelWidth,alignment:.leading)
            Slider(value:Binding(get:{ Double(value) },set:{ value = Int($0.rounded()) }),
                   in:Double(range.lowerBound)...Double(range.upperBound),step:1)
                .controlSize(.small).tint(GlassPalette.accent).accessibilityLabel(label)
            Stepper(value:$value,in:range) { EmptyView() }
                .labelsHidden().controlSize(.small).accessibilityLabel(label)
            Text(L10n.format("%d",value))
                .font(.system(size:11.5,weight:.medium,design:.monospaced))
                .foregroundStyle(GlassPalette.secondaryText(scheme))
                .frame(width:22,alignment:.trailing)
        }
    }
}
