// App Store builds only. Apps sold through the Mac App Store may not download or
// install code themselves (App Review Guideline 2.4.5), so this variant carries
// no downloader, no installer, and no release check. It keeps the same public
// surface as the direct-download AppUpdater so the UI compiles unchanged.
#if APPSTORE
import AppKit

/// A stand-in for the self-updater: the App Store delivers every update, so the
/// only action this class offers is opening the store's Updates page.
@MainActor final class AppUpdater: ObservableObject {
    static let isAppStoreBuild = true
    @Published private(set) var isBusy = false
    @Published private(set) var buttonTitle = L10n.text("Updates come from the App Store")
    private static let updatesPage = URL(string:"macappstore://showUpdatesPage")!

    func checkForUpdates() {
        NSWorkspace.shared.open(Self.updatesPage)
    }
}
#endif
