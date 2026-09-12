// Direct-download builds only. App Store builds compile AppUpdater+AppStore.swift instead.
#if !APPSTORE
import AppKit
import FoldCore

extension UpdateInstallation {
    @discardableResult static func launchWithRecovery(_ destination: URL, arguments: () -> [String], ready: URL, identity: UpdateBundleIdentity? = nil,
                                                      recover: (Error) -> Bool) throws -> NSRunningApplication {
        while true {
            do { return try launchAndConfirm(destination,arguments:arguments(),ready:ready,identity:identity) }
            catch { guard recover(error) else { throw error } }
        }
    }
    static func showRecovery(error: Error, destination: URL, ready: URL) -> Bool {
        let app = NSApplication.shared;app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps:true)
        while true {
            if FileManager.default.fileExists(atPath:ready.path) { return true }
            let alert = NSAlert()
            alert.messageText = L10n.text("macOS could not open the update")
            alert.informativeText = L10n.format("Your previous Macbook Duo is safely backed up. If macOS blocked this downloaded app, go to System Settings → Privacy & Security → Open Anyway, approve Macbook Duo there, then try opening it again. You can restore the previous version at any time.\n\n%@",L10n.text(error.localizedDescription))
            alert.addButton(withTitle:L10n.text("Restore Previous"))
            alert.addButton(withTitle:L10n.text("Open Privacy & Security"))
            alert.addButton(withTitle:L10n.text("Try Opening Again"))
            // This timer exists only inside this explicit recovery dialog. It recognizes
            // a launch approved in System Settings, then stops immediately with the dialog.
            let timer = Timer(timeInterval:0.5,repeats:true) { _ in
                if FileManager.default.fileExists(atPath:ready.path) { NSApp.abortModal() }
            }
            timer.tolerance = 0.1;RunLoop.main.add(timer,forMode:.modalPanel)
            let response = alert.runModal();timer.invalidate()
            if FileManager.default.fileExists(atPath:ready.path) { return true }
            switch response {
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?General")!)
            case .alertThirdButtonReturn: return true
            default: return false
            }
        }
    }
    private static func matches(_ bundle: Bundle, identity: UpdateBundleIdentity) -> Bool {
        guard bundle.bundleIdentifier == identity.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String,
              ReleaseVersion(version) == identity.version,
              let executable = bundle.executableURL, let digest = try? hash(executable) else { return false }
        return identity.matches(bundleIdentifier:bundle.bundleIdentifier,
                                version:bundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String,
                                executableHash:digest)
    }
    @discardableResult static func launchAndConfirm(_ destination: URL, arguments: [String], ready: URL, identity: UpdateBundleIdentity? = nil) throws -> NSRunningApplication {
        if FileManager.default.fileExists(atPath:ready.path),
           let existing = NSWorkspace.shared.runningApplications.first(where:{ application in
               guard !application.isTerminated, let url = application.bundleURL else { return false }
               if let identity {
                   guard application.bundleIdentifier == identity.bundleIdentifier, let bundle = Bundle(url:url) else { return false }
                   return matches(bundle,identity:identity)
               }
               return url.standardizedFileURL == destination.standardizedFileURL
           }) {
            return existing
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = arguments
        var application: NSRunningApplication?, launchError: Error?, responded = false
        NSWorkspace.shared.openApplication(at:destination,configuration:configuration) { app, error in
            DispatchQueue.main.async { application = app;launchError = error;responded = true }
        }
        let timeout = Date().addingTimeInterval(60)
        while !responded, Date() < timeout { RunLoop.current.run(until:Date().addingTimeInterval(0.1)) }
        if let launchError { throw launchError }
        guard let application else { throw UpdateError.invalid(L10n.text("macOS could not open the update. Please install the downloaded app with Finder.")) }
        while !application.isTerminated, !FileManager.default.fileExists(atPath:ready.path), Date() < timeout {
            RunLoop.current.run(until:Date().addingTimeInterval(0.1))
        }
        guard !application.isTerminated, FileManager.default.fileExists(atPath:ready.path) else {
            if !application.isTerminated {
                application.terminate();RunLoop.current.run(until:Date().addingTimeInterval(0.5))
                if !application.isTerminated { application.forceTerminate() }
            }
            throw UpdateError.invalid("The updated app did not finish opening. Your previous version is safely backed up.")
        }
        return application
    }
    @MainActor static func confirmRelaunch() {
        var jobs: [UpdateJob] = []
        if let index = CommandLine.arguments.firstIndex(of:"--update-ready"), index+1 < CommandLine.arguments.count,
           let job = try? readJob(CommandLine.arguments[index+1]) {
            jobs = [job]
        } else {
            // Open Anyway can launch the app without our command-line handoff.
            // Recognize only matching pending jobs, once at launch, without network work.
            let folders = (try? FileManager.default.contentsOfDirectory(at:cache,includingPropertiesForKeys:nil)) ?? []
            jobs = folders.prefix(16).compactMap { try? readJob($0.lastPathComponent) }
        }
        for job in jobs where job.identity.map({ matches(Bundle.main,identity:$0) }) == true {
                try? Data("ready".utf8).write(to:job.folder.appendingPathComponent("ready"),options:.atomic)
        }
        if CommandLine.arguments.contains("--update-rolled-back") {
            let alert = NSAlert();alert.messageText = L10n.text("The previous Macbook Duo was restored")
            alert.informativeText = L10n.text("The update could not finish opening. You can keep using this version or install the latest release from GitHub.")
            NSApp.activate(ignoringOtherApps:true);alert.runModal()
        }
        if CommandLine.arguments.contains("--update-needs-recovery") {
            let alert = NSAlert();alert.messageText = L10n.text("Macbook Duo kept your previous app safe")
            alert.informativeText = L10n.format("A file permission or disk error prevented the update from finishing. Your previous app is at:\n%@\nMove it back to Applications with Finder.",Bundle.main.bundleURL.path)
            NSApp.activate(ignoringOtherApps:true);alert.runModal()
        }
    }
}
#endif
