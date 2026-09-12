import SwiftUI

/// The glass bar that runs under the transparent title bar: brand, tagline,
/// lid angle, appearance and updates. Its leading inset clears the traffic lights.
struct SettingsHeader: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: AppUpdater
    /// Space reserved for the window's close/minimize/zoom buttons.
    static let trafficLightInset: CGFloat = 98
    static let height: CGFloat = 52
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing:10) {
            Image(nsImage:AppBrand.mark).resizable().scaledToFit().frame(width:30,height:30)
                .shadow(color:GlassPalette.electricBlue.opacity(0.35),radius:6,y:2)
                .accessibilityHidden(true)
            VStack(alignment:.leading,spacing:1) {
                Text("Macbook Duo").font(.system(size:16,weight:.semibold,design:.rounded))
                Text(L10n.text("Let your desktop follow the fold."))
                    .font(.system(size:10.5)).foregroundStyle(GlassPalette.secondaryText(scheme))
            }
            Spacer(minLength:8)
            lidPill
            appearanceMenu
            // The App Store delivers updates itself, so its build shows no update button here.
            if !AppUpdater.isAppStoreBuild {
                GlassIconButton(symbol:"arrow.triangle.2.circlepath",label:updater.buttonTitle) { updater.checkForUpdates() }
                    .disabled(updater.isBusy)
            }
        }
        .padding(.leading,Self.trafficLightInset).padding(.trailing,14)
        .frame(height:Self.height)
        .frame(maxWidth:.infinity)
        .background(headerGlass)
    }

    private var headerGlass: some View {
        Rectangle().fill(.ultraThinMaterial)
            .overlay(LinearGradient(colors:[Color.white.opacity(scheme == .dark ? 0.08 : 0.45),.clear],startPoint:.top,endPoint:.bottom))
            .overlay(alignment:.bottom) {
                LinearGradient(colors:[Color.white.opacity(scheme == .dark ? 0.35 : 0.9),Color.white.opacity(0.05)],
                               startPoint:.leading,endPoint:.trailing).frame(height:1)
            }
            .ignoresSafeArea()
    }

    private var lidPill: some View {
        GlassPill {
            HStack(spacing:6) {
                Circle().fill(model.sensorAvailable ? GlassPalette.cyan : Color.orange)
                    .frame(width:6,height:6)
                    .shadow(color:(model.sensorAvailable ? GlassPalette.cyan : Color.orange).opacity(0.8),radius:3)
                Text(model.lidAngle.map { L10n.format("Lid %.0f°",$0) } ?? L10n.text("Looking for sensor"))
                    .font(.system(size:11.5,weight:.medium,design:.monospaced))
            }
        }
        .accessibilityLabel(model.lidAngle.map { L10n.format("Lid %.0f°",$0) } ?? L10n.text("Looking for sensor"))
    }

    private var appearanceMenu: some View {
        Menu {
            Picker(L10n.text("Appearance"),selection:$model.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title,systemImage:appearance.symbol).tag(appearance)
                }
            }
        } label: {
            Image(systemName:model.appearance.symbol)
                .font(.system(size:13,weight:.semibold))
                .foregroundStyle(GlassPalette.accentText(scheme))
                .frame(width:16,height:16)
                .padding(8)
                .glassSurface(cornerRadius:GlassPalette.pillRadius,interactive:true,shadowed:false)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .accessibilityLabel(L10n.text("Appearance"))
        .help(L10n.format("Appearance: %@",model.appearance.title))
    }
}
