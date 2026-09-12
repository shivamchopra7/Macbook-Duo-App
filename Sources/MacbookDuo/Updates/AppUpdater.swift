// Direct-download builds only. App Store builds compile AppUpdater+AppStore.swift instead.
#if !APPSTORE
import AppKit
import FoldCore

/// One request only when the user asks. No scheduled checks, analytics, or updater daemon.
@MainActor final class AppUpdater: ObservableObject {
    /// Direct-download builds update themselves; the App Store variant never does.
    static let isAppStoreBuild = false
    @Published private(set) var isBusy = false
    @Published private(set) var buttonTitle = L10n.text("Check for updates")
    private let releases = URL(string:"https://github.com/shivamchopra7/Macbook-Duo-App/releases/latest")!

    func checkForUpdates() {
        guard !isBusy else { return }
        isBusy = true;buttonTitle = L10n.text("Checking…")
        Task {
            defer { isBusy = false;buttonTitle = L10n.text("Check for updates") }
            do {
                guard let update = try await Self.findUpdate() else {
                    show(L10n.text("You’re up to date"),message:L10n.format("Macbook Duo %@ is the latest stable release.",Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? ""))
                    return
                }
                let alert = NSAlert()
                alert.messageText = L10n.format("Macbook Duo %@ is available",update.tag)
                alert.informativeText = L10n.text("Download, verify, and install the update, then reopen Macbook Duo. Your settings will be kept. macOS may ask you to allow the updated app or Screen Recording again.")
                alert.addButton(withTitle:L10n.text("Install & Relaunch"))
                alert.addButton(withTitle:L10n.text("Later"))
                alert.addButton(withTitle:L10n.text("View release"))
                NSApp.activate(ignoringOtherApps:true)
                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    buttonTitle = L10n.text("Updating…")
                    let destination = try UpdateInstallation.installLocation()
                    let archive = try await UpdateDownload.fetch(update.archive,maximum:ReleaseUpdate.maximumArchiveBytes)
                    guard archive.count == update.archiveSize else { throw UpdateError.invalid("The installer download was incomplete. Please try again.") }
                    let checksums = try await UpdateDownload.fetch(update.checksums,maximum:16_384)
                    let job = try await Task.detached(priority:.utility) {
                        try UpdateInstallation.prepare(archive:archive,checksums:checksums,update:update,destination:destination)
                    }.value
                    // A detached helper waits for our normal shutdown before touching the bundle.
                    try await UpdateInstallation.startHelper(job)
                    NSApp.terminate(nil)
                case .alertThirdButtonReturn: NSWorkspace.shared.open(update.releasePage)
                default: break
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = L10n.text("Macbook Duo could not update")
                alert.informativeText = L10n.text(error.localizedDescription)
                alert.addButton(withTitle:L10n.text("OK"));alert.addButton(withTitle:L10n.text("Open downloads"))
                NSApp.activate(ignoringOtherApps:true)
                if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(releases) }
            }
        }
    }

    static func findUpdate() async throws -> ReleaseUpdate? {
        let url = URL(string:"https://api.github.com/repos/\(ReleaseUpdate.repository)/releases/latest")!
        let data = try await UpdateDownload.fetch(url,maximum:1_048_576)
        return try ReleaseUpdate.newerRelease(data:data,installed:Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")
    }
    private func show(_ title: String, message: String) {
        let alert = NSAlert();alert.messageText = title;alert.informativeText = message
        NSApp.activate(ignoringOtherApps:true);alert.runModal()
    }
}
#endif
