import Foundation
import CryptoKit
import FoldCore

enum UpdateInstallation {
    static var cache: URL {
        FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("com.shivamchopra.macbookduo/updates",isDirectory:true)
    }
    static func hash(_ file: URL) throws -> String {
        SHA256.hash(data:try Data(contentsOf:file)).map { String(format:"%02x",$0) }.joined()
    }
    static func installLocation() throws -> URL {
        let destination = Bundle.main.bundleURL.standardizedFileURL
        let roots = [URL(fileURLWithPath:"/Applications",isDirectory:true),
                     FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications",isDirectory:true)]
        guard roots.contains(destination.deletingLastPathComponent()), destination.lastPathComponent == "Macbook Duo.app",
              destination.resolvingSymlinksInPath() == destination,
              (try? destination.resourceValues(forKeys:[.volumeIsReadOnlyKey]).volumeIsReadOnly) == false,
              FileManager.default.isWritableFile(atPath:destination.path),
              FileManager.default.isWritableFile(atPath:destination.deletingLastPathComponent().path) else {
            throw UpdateError.invalid("Move Macbook Duo to Applications and open it there before updating. If Applications needs an administrator password, install the downloaded update with Finder.")
        }
        return destination
    }
    static func prepare(archive: Data, checksums: Data, update: ReleaseUpdate, destination: URL, installAfterExit: Bool = true) throws -> UpdateJob {
        try ReleaseUpdate.verifyChecksum(archive:archive,manifest:checksums)
        try UpdateArchive.validate(archive)
        let files = FileManager.default, token = UUID().uuidString
        let folder = cache.appendingPathComponent(token,isDirectory:true)
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".MacbookDuo-update-\(token)",isDirectory:true)
        try files.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        do {
            try files.createDirectory(at:staging,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
            try UpdateArchive.extract(archive,into:staging)
            let candidate = staging.appendingPathComponent("Macbook Duo.app",isDirectory:true)
            try validateBundle(candidate,version:update.version)
            // URLSession is not a browser download and does not add quarantine itself.
            // Preserve macOS's downloaded-app assessment when LaunchServices opens it.
            let quarantine = "0081;\(String(Int(Date().timeIntervalSince1970),radix:16));Macbook Duo;\(token)"
            let marked = quarantine.withCString { value in
                setxattr(candidate.path,"com.apple.quarantine",value,strlen(value),0,0)
            }
            guard marked == 0 else { throw UpdateError.invalid("macOS could not mark the downloaded app for its normal security check. Please install it with Finder.") }
            let digest = try hash(candidate.appendingPathComponent("Contents/MacOS/MacbookDuo"))
            let job = UpdateJob(token:token,destination:destination.path,staging:staging.path,
                                version:update.tag,parentPID:ProcessInfo.processInfo.processIdentifier,executableHash:digest,installAfterExit:installAfterExit)
            try JSONEncoder().encode(job).write(to:folder.appendingPathComponent("job.json"),options:.atomic)
            let helper = folder.appendingPathComponent("Installer.app",isDirectory:true)
            try UpdateHandoff.writeHelperBundle(from:Bundle.main.bundleURL,to:helper)
            try command("/usr/bin/codesign",["--verify","--deep","--strict",helper.path])
            return job
        } catch {
            try? files.removeItem(at:staging);try? files.removeItem(at:folder);throw error
        }
    }
    @discardableResult static func startHelper(_ job: UpdateJob) async throws -> Process {
        let helper = Process()
        helper.executableURL = job.folder.appendingPathComponent("Installer.app/Contents/MacOS/MacbookDuo")
        helper.arguments = ["--finish-update",job.token]
        helper.standardInput = FileHandle.nullDevice;helper.standardOutput = FileHandle.nullDevice;helper.standardError = FileHandle.nullDevice
        do {
            try helper.run()
            try await UpdateHandoff.waitUntilReady(isRunning:{ helper.isRunning }) {
                guard let data = try? Data(contentsOf:job.folder.appendingPathComponent("helper-ready.json")),
                      let ready = try? JSONDecoder().decode(UpdateHelperReady.self,from:data) else { return false }
                return ready.processID == helper.processIdentifier && ready.executableHash == job.executableHash
            }
            return helper
        }
        catch {
            if helper.isRunning { helper.terminate();try? await Task.sleep(nanoseconds:200_000_000) }
            if helper.isRunning { kill(helper.processIdentifier,SIGKILL) }
            try? FileManager.default.removeItem(atPath:job.staging)
            try? FileManager.default.removeItem(at:job.folder)
            throw error
        }
    }
    static func command(_ path: String, _ arguments: [String]) throws {
        let process = Process();process.executableURL = URL(fileURLWithPath:path);process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice;process.standardError = FileHandle.nullDevice
        try process.run();process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw UpdateError.invalid("The downloaded app failed validation or could not be installed. Nothing was replaced.")
        }
    }
    static func validateBundle(_ app: URL, version: ReleaseVersion,
                               architecture: ReleaseArchitecture = .current) throws {
        let files = FileManager.default
        guard let walker = files.enumerator(at:app,includingPropertiesForKeys:[.isSymbolicLinkKey,.isRegularFileKey,.isDirectoryKey]) else {
            throw UpdateError.invalid("The installer contains no app.")
        }
        for case let entry as URL in walker {
            let values = try entry.resourceValues(forKeys:[.isSymbolicLinkKey,.isRegularFileKey,.isDirectoryKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true || values.isDirectory == true else {
                throw UpdateError.invalid("The installer contains unsupported linked files.")
            }
        }
        let info = try PropertyListSerialization.propertyList(from:Data(contentsOf:app.appendingPathComponent("Contents/Info.plist")),format:nil) as? [String:Any]
        let operatingSystem = ProcessInfo.processInfo.operatingSystemVersion
        let currentOS = ReleaseVersion("\(operatingSystem.majorVersion).\(operatingSystem.minorVersion).\(operatingSystem.patchVersion)")!
        guard info?["CFBundleIdentifier"] as? String == "com.shivamchopra.macbookduo",
              info?["CFBundleExecutable"] as? String == "MacbookDuo",
              info?["CFBundlePackageType"] as? String == "APPL",
              let string = info?["CFBundleShortVersionString"] as? String, ReleaseVersion(string) == version,
              let minimum = info?["LSMinimumSystemVersion"] as? String, let minimumVersion = ReleaseVersion(minimum), minimumVersion <= currentOS else {
            throw UpdateError.invalid("The downloaded app has the wrong identity or version, or requires a newer macOS.")
        }
        let binary = app.appendingPathComponent("Contents/MacOS/MacbookDuo")
        guard files.isExecutableFile(atPath:binary.path) else { throw UpdateError.invalid("The downloaded app is not executable.") }
        let executableArchitecture = architecture == .arm64
            ? NSBundleExecutableArchitectureARM64 : NSBundleExecutableArchitectureX86_64
        guard Bundle(url:app)?.executableArchitectures?.contains(NSNumber(value:executableArchitecture)) == true else {
            throw UpdateError.invalid("The downloaded app does not support this Mac’s processor.")
        }
        try command("/usr/bin/codesign",["--verify","--deep","--strict",app.path])
    }
    static func readJob(_ token: String) throws -> UpdateJob {
        guard UUID(uuidString:token)?.uuidString == token else { throw UpdateError.invalid("Invalid update handoff.") }
        let folder = cache.appendingPathComponent(token,isDirectory:true)
        guard folder.resolvingSymlinksInPath() == folder else { throw UpdateError.invalid("Invalid update location.") }
        let job = try JSONDecoder().decode(UpdateJob.self,from:Data(contentsOf:folder.appendingPathComponent("job.json")))
        let destination = URL(fileURLWithPath:job.destination,isDirectory:true)
        let roots = [URL(fileURLWithPath:"/Applications",isDirectory:true),
                     FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications",isDirectory:true)]
        guard job.token == token, job.parentPID > 1, roots.contains(destination.deletingLastPathComponent()),
              destination.lastPathComponent == "Macbook Duo.app", destination.resolvingSymlinksInPath() == destination,
              job.staging == destination.deletingLastPathComponent().appendingPathComponent(".MacbookDuo-update-\(token)",isDirectory:true).path else {
            throw UpdateError.invalid("Invalid update destination.")
        }
        return job
    }
    /// Called before creating the app for the copied helper, which never opens a window.
    static func finishUpdate(token: String) -> Int32 {
        guard let job = try? readJob(token) else { return 1 }
        let destination = URL(fileURLWithPath:job.destination,isDirectory:true)
        let staging = URL(fileURLWithPath:job.staging,isDirectory:true)
        let candidate = staging.appendingPathComponent("Macbook Duo.app",isDirectory:true)
        let backup = staging.appendingPathComponent("Previous.app",isDirectory:true)
        let files = FileManager.default
        var installed = false
        defer {
            // Keep the original app available if a filesystem error prevented restoration.
            if installed || (!files.fileExists(atPath:backup.path) && files.fileExists(atPath:destination.path)) {
                try? files.removeItem(at:staging);try? files.removeItem(at:job.folder)
            }
        }
        do {
            guard let version = ReleaseVersion(job.version), staging.resolvingSymlinksInPath() == staging else {
                throw UpdateError.invalid("The prepared update changed location.")
            }
            try validateBundle(candidate,version:version)
            guard try hash(candidate.appendingPathComponent("Contents/MacOS/MacbookDuo")) == job.executableHash else {
                throw UpdateError.invalid("The prepared update changed before the helper started.")
            }
            let acknowledgment = UpdateHelperReady(processID:ProcessInfo.processInfo.processIdentifier,executableHash:job.executableHash)
            try JSONEncoder().encode(acknowledgment).write(to:job.folder.appendingPathComponent("helper-ready.json"),options:.atomic)
            let deadline = Date().addingTimeInterval(30)
            while kill(job.parentPID,0) == 0, Date() < deadline { Thread.sleep(forTimeInterval:0.1) }
            guard job.installAfterExit, kill(job.parentPID,0) != 0 else { return 1 }
            try validateBundle(candidate,version:version)
            let oldInfo = try PropertyListSerialization.propertyList(from:Data(contentsOf:destination.appendingPathComponent("Contents/Info.plist")),format:nil) as? [String:Any]
            guard try hash(candidate.appendingPathComponent("Contents/MacOS/MacbookDuo")) == job.executableHash,
                  oldInfo?["CFBundleIdentifier"] as? String == "com.shivamchopra.macbookduo",
                  let old = oldInfo?["CFBundleShortVersionString"] as? String, let oldVersion = ReleaseVersion(old), oldVersion < version else {
                throw UpdateError.invalid("The installed app changed while the update was downloading.")
            }
            try UpdateReplacement.install(staged:candidate,destination:destination,backup:backup) {
                let ready = job.folder.appendingPathComponent("ready")
                try launchWithRecovery(destination,arguments:{ ["--update-ready",token] },ready:ready,identity:job.identity) { error in
                    showRecovery(error: error, destination:destination, ready:ready)
                }
            }
            installed = true
            return 0
        } catch {
            if kill(job.parentPID,0) != 0 {
                if files.fileExists(atPath:backup.path) {
                    // Launch the retained original itself; the alert points to its recovery location.
                    try? command("/usr/bin/open",[backup.path,"--args","--update-needs-recovery"])
                } else if files.fileExists(atPath:destination.path) {
                    try? command("/usr/bin/open",[destination.path,"--args","--update-rolled-back"])
                }
            }
            return 1
        }
    }
}
