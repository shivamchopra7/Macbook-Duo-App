import SwiftUI

/// The action row and the hint row under the two panes. Every control the
/// original footer offered is still here: enable/pause, the desktop test,
/// replay, status, the privacy shortcut, quit, and the two quick toggles.
struct SettingsFooter: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment:.leading,spacing:7) {
            actions
            hints
        }
    }

    private var enableTitle: String {
        if model.checkingPermission { return L10n.text("Checking…") }
        return model.enabled ? AppBrand.text("Pause %@") : AppBrand.text("Enable %@")
    }

    private var actions: some View {
        HStack(spacing:8) {
            // Following the lid needs the hardware sensor. Without it both actions
            // are unavailable, so they read as a hardware requirement rather than
            // as buttons that silently do nothing.
            Button(enableTitle) { if model.enabled { model.pause() } else { model.enable() } }
                .buttonStyle(.glassProminent).disabled(model.checkingPermission || !model.sensorAvailable)
                .accessibilityLabel(enableTitle)
                .help(model.sensorAvailable ? enableTitle : L10n.text("Needs a MacBook with a lid-angle sensor. Use Replay to see the effects."))
            Button(model.demoRunning ? L10n.text("Testing…") : L10n.text("Test desktop · 8 sec")) { model.testDesktop() }
                .buttonStyle(.glassQuiet).disabled(model.demoRunning || model.checkingPermission || !model.sensorAvailable)
                .accessibilityLabel(L10n.text("Test desktop · 8 sec"))
                .help(model.sensorAvailable ? L10n.text("Test desktop · 8 sec") : L10n.text("Needs a MacBook with a lid-angle sensor. Use Replay to see the effects."))
            Button { model.playPreview() } label: {
                HStack(spacing:5) { Image(systemName:"play.fill").font(.system(size:10,weight:.bold));Text(L10n.text("Replay")) }
            }
            .buttonStyle(.glassQuiet).disabled(model.previewPlaying)
            .accessibilityLabel(L10n.text("Replay"))
            Text(model.status).font(.system(size:11)).foregroundStyle(GlassPalette.secondaryText(scheme))
                .lineLimit(2).minimumScaleFactor(0.9).help(model.status)
                .frame(maxWidth:.infinity,alignment:.trailing)
                .accessibilityLabel(model.status)
            if !model.hasPermission {
                GlassIconButton(symbol:"gearshape",label:L10n.text("Open Screen Recording settings")) { model.openPrivacy() }
            }
            Button(L10n.text("Quit")) { NSApp.terminate(nil) }
                .buttonStyle(.glassQuiet).help(AppBrand.text("Quit %@"))
                .accessibilityLabel(AppBrand.text("Quit %@"))
        }
    }

    private var previewMode: String {
        if model.previewPlaying { return L10n.text("Replaying") }
        return model.followLid ? L10n.text("Live preview") : L10n.text("Manual preview")
    }

    private var hints: some View {
        HStack(spacing:5) {
            Text(previewMode)
            dot
            Image(systemName:"escape");Text(L10n.text("to pause"))
            dot
            Text(L10n.text("⌃⌥⌘F anywhere"))
            Spacer()
            Toggle(L10n.text("Menu bar icon"),isOn:$model.showInMenuBar)
                .toggleStyle(.checkbox).controlSize(.mini).tint(GlassPalette.accent)
                .accessibilityLabel(L10n.text("Menu bar icon"))
                .help(L10n.text("Show the app icon in the menu bar. With it hidden, open the app from Applications or Spotlight to bring this window back."))
            dot
            Toggle(L10n.text("Open at login"),isOn:Binding(get:{ model.launchAtLogin },set:{ model.setLaunchAtLogin($0) }))
                .toggleStyle(.checkbox).controlSize(.mini).tint(GlassPalette.accent)
                .accessibilityLabel(L10n.text("Open at login"))
                .help(L10n.text("Start the app when you log in. It opens paused; following begins when you enable it."))
            dot
            if model.reducedMotion { Text(L10n.text("Reduce Motion on"));dot }
            Text(L10n.text("On your Mac only")).foregroundStyle(GlassPalette.accentText(scheme))
        }
        .font(.system(size:10)).foregroundStyle(GlassPalette.secondaryText(scheme))
    }

    private var dot: some View { Text("·").accessibilityHidden(true) }
}
