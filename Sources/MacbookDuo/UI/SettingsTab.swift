import SwiftUI

/// The four pages of the settings pane. `rawValue` is also the value accepted
/// by the `--tab` diagnostic launch argument.
enum SettingsTab: String, CaseIterable, Identifiable {
    case effects, motion, look, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .effects: return L10n.text("Effects")
        case .motion: return L10n.text("Motion")
        case .look: return L10n.text("Look")
        case .about: return L10n.text("About")
        }
    }

    var symbol: String {
        switch self {
        case .effects: return "sparkles"
        case .motion: return "figure.walk.motion"
        case .look: return "paintpalette"
        case .about: return "info.circle"
        }
    }

    /// `--tab motion` picks the page a screenshot should open on. Unknown or
    /// missing values fall back to the first page.
    static func fromLaunchArguments(_ arguments: [String] = CommandLine.arguments) -> SettingsTab {
        guard let index = arguments.firstIndex(of:"--tab"), index+1 < arguments.count else { return .effects }
        return SettingsTab(rawValue:arguments[index+1].lowercased()) ?? .effects
    }
}

/// A glass rail of four pills. The selected pill's tinted slab slides between
/// positions with a matched geometry effect.
struct SettingsTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing:4) {
            ForEach(SettingsTab.allCases) { tab in
                Button { withAnimation(GlassPalette.transition) { selection = tab } } label: {
                    HStack(spacing:5) {
                        Image(systemName:tab.symbol).font(.system(size:11,weight:.semibold))
                        Text(tab.title).font(.system(size:12,weight:.semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.white : Color.primary)
                    .padding(.horizontal,10).padding(.vertical,6)
                    .frame(maxWidth:.infinity)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(LinearGradient(colors:[GlassPalette.electricBlue,GlassPalette.indigo],
                                                     startPoint:.topLeading,endPoint:.bottomTrailing))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35),lineWidth:1))
                                .matchedGeometryEffect(id:"tab",in:namespace)
                        }
                    }
                    .contentShape(Capsule())
                    .contentShape(.focusEffect,Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                .help(tab.title)
            }
        }
        .padding(4)
        .glassSurface(cornerRadius:GlassPalette.pillRadius,shadowed:false)
        .accessibilityElement(children:.contain)
    }
}
