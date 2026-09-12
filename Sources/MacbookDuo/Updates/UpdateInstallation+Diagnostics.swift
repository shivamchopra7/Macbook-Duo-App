import AppKit
import FoldCore

extension UpdateInstallation {
    /// Stages a supplied, verified package and observes the real helper's acknowledgment.
    /// The diagnostic job cannot replace the app, even if its parent is interrupted.
    static func checkHandoff(archive: URL, manifest: URL, version: String) async throws {
        let destination = try installLocation()
        guard let parsed = ReleaseVersion(version), parsed > ReleaseVersion("0.0")!,
              (try archive.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max) <= ReleaseUpdate.maximumArchiveBytes,
              (try manifest.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max) <= 16_384 else {
            throw UpdateError.invalid("Invalid handoff verification package.")
        }
        let tag = version.hasPrefix("v") ? version : "v"+version
        let data = try Data(contentsOf:archive), checksums = try Data(contentsOf:manifest)
        let names = [(ReleaseUpdate.archiveName,data.count),(ReleaseUpdate.checksumName,checksums.count)]
        let assets: [[String:Any]] = names.map { ["name":$0.0,"size":$0.1,"browser_download_url":"https://github.com/\(ReleaseUpdate.repository)/releases/download/\(tag)/\($0.0)"] }
        let metadata = try JSONSerialization.data(withJSONObject:["tag_name":tag,"draft":false,"prerelease":false,"assets":assets])
        guard let update = try ReleaseUpdate.newerRelease(data:metadata,installed:"0.0") else { throw UpdateError.invalid("Invalid handoff verification version.") }
        let job = try prepare(archive:data,checksums:checksums,update:update,destination:destination,installAfterExit:false)
        defer {
            try? FileManager.default.removeItem(atPath:job.staging)
            try? FileManager.default.removeItem(at:job.folder)
        }
        let helper = try await startHelper(job)
        helper.terminate();try? await Task.sleep(nanoseconds:200_000_000)
        if helper.isRunning { kill(helper.processIdentifier,SIGKILL);try? await Task.sleep(nanoseconds:200_000_000) }
        guard !helper.isRunning, kill(job.parentPID,0) == 0 else { throw UpdateError.invalid("The diagnostic helper could not stop normally.") }
        try? FileManager.default.removeItem(atPath:job.staging)
        try? FileManager.default.removeItem(at:job.folder)
        guard !FileManager.default.fileExists(atPath:job.staging), !FileManager.default.fileExists(atPath:job.folder.path) else {
            throw UpdateError.invalid("The handoff succeeded, but its scratch files could not be removed.")
        }
        print("Helper handoff verified: PID \(helper.processIdentifier), SHA-256 \(job.executableHash); helper stopped, parent alive, replacement disabled, staging cleaned.")
    }
    /// Explicit diagnostics only: never chooses the installed app as an output location.
    static func checkPackage(archive: URL, manifest: URL, version: String, output: URL) throws {
        let folder = output.standardizedFileURL
        guard folder.path == output.path, !folder.path.hasPrefix("/Applications/"),
              !folder.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path+"/"),
              !FileManager.default.fileExists(atPath:folder.path), let version = ReleaseVersion(version) else {
            throw UpdateError.invalid("Choose a new scratch directory outside Applications for package verification.")
        }
        guard let architecture = ReleaseArchitecture(archiveName:archive.lastPathComponent) else {
            throw UpdateError.invalid("Use the canonical Macbook-Duo-mac.zip or Macbook-Duo-Intel.zip archive name for package verification.")
        }
        let archiveSize = try archive.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        let manifestSize = try manifest.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard archiveSize <= ReleaseUpdate.maximumArchiveBytes, manifestSize <= 16_384 else { throw UpdateError.invalid("Package verification input exceeds the download limits.") }
        let data = try Data(contentsOf:archive)
        try ReleaseUpdate.verifyChecksum(archive:data,manifest:Data(contentsOf:manifest),architecture:architecture)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        do {
            try UpdateArchive.extract(data,into:folder)
            try validateBundle(folder.appendingPathComponent("Macbook Duo.app",isDirectory:true),version:version,
                               architecture:architecture)
        } catch { try? FileManager.default.removeItem(at:folder);throw error }
    }

    /// Uses disposable apps to exercise the same replacement and LaunchServices
    /// readiness functions as a real update, including restoration after launch failure.
    static func checkInstallerFixture(output: URL) throws {
        let files = FileManager.default, folder = output.standardizedFileURL
        guard folder.path == output.path, folder.lastPathComponent.hasPrefix("MacbookDuo-update-fixture-"),
              folder.resolvingSymlinksInPath() == folder,
              !folder.path.hasPrefix("/Applications/"), !folder.path.contains("/Applications/"),
              !files.fileExists(atPath:folder.path), let executable = Bundle.main.executableURL else {
            throw UpdateError.invalid("Choose a new scratch directory named MacbookDuo-update-fixture-… outside Applications.")
        }
        try files.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        func bundle(_ name: String, marker: String) throws -> URL {
            let app = folder.appendingPathComponent(name,isDirectory:true)
            let macOS = app.appendingPathComponent("Contents/MacOS",isDirectory:true)
            try files.createDirectory(at:macOS,withIntermediateDirectories:true)
            try files.copyItem(at:executable,to:macOS.appendingPathComponent("MacbookDuo"))
            try files.createDirectory(at:app.appendingPathComponent("Contents/Resources",isDirectory:true),withIntermediateDirectories:true)
            let info: [String:Any] = ["CFBundleIdentifier":"com.shivamchopra.macbookduo.update-fixture", "CFBundleExecutable":"MacbookDuo",
                                     "CFBundleName":"Macbook Duo Update Fixture", "CFBundlePackageType":"APPL", "LSUIElement":true,
                                     "CFBundleShortVersionString":"0.0.1", "CFBundleVersion":"1", "LSMinimumSystemVersion":"13.0"]
            try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:app.appendingPathComponent("Contents/Info.plist"))
            try Data(marker.utf8).write(to:app.appendingPathComponent("Contents/Resources/fixture-version"))
            try command("/usr/bin/codesign",["--force","--sign","-",app.path])
            return app
        }
        let destination = try bundle("Macbook Duo.app",marker:"old")
        let helper = folder.appendingPathComponent("Installer.app",isDirectory:true)
        try UpdateHandoff.writeHelperBundle(from:destination,to:helper)
        try command("/usr/bin/codesign",["--verify","--deep","--strict",helper.path])
        let bootstrap = Process();bootstrap.executableURL = helper.appendingPathComponent("Contents/MacOS/MacbookDuo")
        // Exercise the real bundle-copy helper path with sealed Info.plist/resources.
        // No job exists for this UUID, so no installation target can be modified.
        bootstrap.arguments = ["--finish-update",UUID().uuidString]
        bootstrap.standardOutput = FileHandle.nullDevice;bootstrap.standardError = FileHandle.nullDevice
        try bootstrap.run();bootstrap.waitUntilExit()
        guard bootstrap.terminationReason == .exit, bootstrap.terminationStatus == 1 else {
            throw UpdateError.invalid("The signed helper bundle could not start normally.")
        }
        let candidate = try bundle("Candidate.app",marker:"new")
        let backup = folder.appendingPathComponent("Backup.app",isDirectory:true), ready = folder.appendingPathComponent("ready")
        var application: NSRunningApplication?
        defer {
            if let application, !application.isTerminated { application.forceTerminate() }
        }
        try UpdateReplacement.install(staged:candidate,destination:destination,backup:backup) {
            application = try launchAndConfirm(destination,arguments:["--update-fixture-ready",ready.path],ready:ready)
        }
        guard try String(contentsOf:destination.appendingPathComponent("Contents/Resources/fixture-version"),encoding:.utf8) == "new",
              try String(contentsOf:backup.appendingPathComponent("Contents/Resources/fixture-version"),encoding:.utf8) == "old" else {
            throw UpdateError.invalid("Fixture replacement did not preserve the expected versions.")
        }
        let identity = UpdateBundleIdentity(bundleIdentifier:"com.shivamchopra.macbookduo.update-fixture",version:ReleaseVersion("0.0.1")!,
                                           executableHash:try hash(destination.appendingPathComponent("Contents/MacOS/MacbookDuo")))
        let recognized = try launchAndConfirm(folder.appendingPathComponent("SimulatedTranslocation.app",isDirectory:true),
                                             arguments:[],ready:ready,identity:identity)
        guard recognized.processIdentifier == application?.processIdentifier else {
            throw UpdateError.invalid("Fixture did not recognize the already approved app at a different path.")
        }
        application?.terminate();RunLoop.current.run(until:Date().addingTimeInterval(0.5))
        if let application, !application.isTerminated { application.forceTerminate() }
        try files.removeItem(at:backup);try files.removeItem(at:ready)
        let failed = try bundle("Failed.app",marker:"failed")
        var rolledBack = false
        do {
            try UpdateReplacement.install(staged:failed,destination:destination,backup:backup) {
                try launchAndConfirm(destination,arguments:["--update-fixture-fail"],ready:ready)
            }
        } catch { rolledBack = true }
        guard rolledBack, try String(contentsOf:destination.appendingPathComponent("Contents/Resources/fixture-version"),encoding:.utf8) == "new",
              try String(contentsOf:failed.appendingPathComponent("Contents/Resources/fixture-version"),encoding:.utf8) == "failed",
              !files.fileExists(atPath:backup.path) else { throw UpdateError.invalid("Fixture failed to restore the previous version.") }
        var retries = 0
        try UpdateReplacement.install(staged:failed,destination:destination,backup:backup) {
            application = try launchWithRecovery(destination,arguments:{ retries == 0 ? ["--update-fixture-fail"] : ["--update-fixture-ready",ready.path] },ready:ready) { _ in
                retries += 1;return retries == 1
            }
        }
        guard retries == 1, try String(contentsOf:destination.appendingPathComponent("Contents/Resources/fixture-version"),encoding:.utf8) == "failed" else {
            throw UpdateError.invalid("Fixture recovery did not retry the validated candidate.")
        }
        try Data("{\"helperBootstrap\":true,\"launchServices\":true,\"readyHandshake\":true,\"replacement\":true,\"failedLaunchRollback\":true,\"explicitRecoveryRetry\":true,\"pathIndependentIdentity\":true}\n".utf8)
            .write(to:folder.appendingPathComponent("result.json"))
    }
}
