import SwiftUI

/// The optics of the effect and the window's own appearance.
struct LookTab: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            GlassSliderRow(label:L10n.text("Perspective"),value:$model.perspective,range:0...1,text:percent(model.perspective))
            GlassSliderRow(label:L10n.text("Softness"),value:$model.blur,range:0...1,text:percent(model.blur))
            GlassSliderRow(label:L10n.text("Shadow"),value:$model.shadow,range:0...1,text:percent(model.shadow))
            divider
            HStack(spacing:10) {
                Text(L10n.text("Appearance")).font(.system(size:11.5,weight:.medium)).frame(width:92,alignment:.leading)
                GlassSegmentedPicker(label:L10n.text("Appearance"),segments:AppAppearance.allCases.map {
                    .init(option:$0,title:$0.title,symbol:$0.symbol,help:L10n.format("Appearance: %@",$0.title))
                },selection:$model.appearance)
            }
            divider
            GlassToggleRow(label:L10n.text("Menu bar icon"),isOn:$model.showInMenuBar,
                           help:L10n.text("Show the Macbook Duo icon in the menu bar. With it hidden, open Macbook Duo from Applications or Spotlight to bring this window back."))
            GlassCaption(text:L10n.text("Show the Macbook Duo icon in the menu bar. With it hidden, open Macbook Duo from Applications or Spotlight to bring this window back."),size:10.5)
            GlassToggleRow(label:L10n.text("Open at login"),
                           isOn:Binding(get:{ model.launchAtLogin },set:{ model.setLaunchAtLogin($0) }),
                           help:L10n.text("Start Macbook Duo when you log in. It opens paused; following begins when you enable it."))
            GlassCaption(text:L10n.text("Start Macbook Duo when you log in. It opens paused; following begins when you enable it."),size:10.5)
        }
    }

    private func percent(_ x: Double) -> String { String(format:"%.0f%%",x*100) }
    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(scheme == .dark ? 0.12 : 0.08)).frame(height:1).padding(.vertical,1)
    }
}
