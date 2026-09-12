import SwiftUI

/// One glass rail holding a row of equal segments. The selected segment's
/// tinted slab slides between positions with a matched geometry effect.
struct GlassSegmentedPicker<Option: Hashable>: View {
    struct Segment {
        let option: Option
        let title: String
        var symbol: String? = nil
        var help: String? = nil
    }

    let label: String
    let segments: [Segment]
    @Binding var selection: Option
    var compact = false
    @Namespace private var namespace
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing:3) {
            ForEach(segments,id:\.option) { segment in
                Button { withAnimation(GlassPalette.transition) { selection = segment.option } } label: {
                    HStack(spacing:4) {
                        if let symbol = segment.symbol {
                            Image(systemName:symbol).font(.system(size:10,weight:.semibold))
                        }
                        if !compact || segment.symbol == nil {
                            Text(segment.title).font(.system(size:11,weight:.medium)).lineLimit(1)
                        }
                    }
                    .foregroundStyle(selection == segment.option ? Color.white : Color.primary)
                    .padding(.horizontal,8).padding(.vertical,5)
                    .frame(maxWidth:.infinity)
                    .background {
                        if selection == segment.option {
                            RoundedRectangle(cornerRadius:8,style:.continuous)
                                .fill(LinearGradient(colors:[GlassPalette.electricBlue,GlassPalette.indigo],
                                                     startPoint:.topLeading,endPoint:.bottomTrailing))
                                .matchedGeometryEffect(id:"selection",in:namespace)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius:8,style:.continuous))
                    .contentShape(.focusEffect,RoundedRectangle(cornerRadius:8,style:.continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(segment.title)
                .accessibilityAddTraits(selection == segment.option ? [.isSelected] : [])
                .help(segment.help ?? segment.title)
            }
        }
        .padding(3)
        .glassSurface(cornerRadius:11,shadowed:false)
        .accessibilityElement(children:.contain)
        .accessibilityLabel(label)
    }
}
