import Foundation

/// App Translocation changes a downloaded app's path, but not these verified bytes.
public struct UpdateBundleIdentity: Sendable {
    public let bundleIdentifier: String
    public let version: ReleaseVersion
    public let executableHash: String
    public init(bundleIdentifier: String, version: ReleaseVersion, executableHash: String) {
        self.bundleIdentifier = bundleIdentifier;self.version = version;self.executableHash = executableHash
    }
    public func matches(bundleIdentifier: String?, version: String?, executableHash: String) -> Bool {
        self.bundleIdentifier == bundleIdentifier && version.flatMap(ReleaseVersion.init) == self.version &&
        self.executableHash.count == 64 && self.executableHash == executableHash
    }
}

public enum UpdateHandoff {
    /// Developer ID/Development signatures seal the containing Info.plist and resources.
    /// Re-create the complete trusted bundle, not an executable detached from its seal.
    public static func writeHelperBundle(from app: URL, to helper: URL) throws {
        let files = FileManager.default
        guard app.pathExtension == "app", app.resolvingSymlinksInPath() == app.standardizedFileURL,
              !files.fileExists(atPath:helper.path),
              let entries = files.enumerator(at:app,includingPropertiesForKeys:[.isSymbolicLinkKey,.isDirectoryKey,.isRegularFileKey]) else {
            throw UpdateError.invalid("The installed app could not prepare its signed updater bundle.")
        }
        try files.createDirectory(at:helper,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        do {
            let sourcePath = app.resolvingSymlinksInPath().path
            for case let entry as URL in entries {
                let values = try entry.resourceValues(forKeys:[.isSymbolicLinkKey,.isDirectoryKey,.isRegularFileKey])
                let entryPath = entry.resolvingSymlinksInPath().path
                guard values.isSymbolicLink != true, values.isDirectory == true || values.isRegularFile == true,
                      entryPath.hasPrefix(sourcePath+"/") else {
                    throw UpdateError.invalid("The installed app contains an unsupported helper resource.")
                }
                let destination = helper.appendingPathComponent(String(entryPath.dropFirst(sourcePath.count+1)))
                if values.isDirectory == true {
                    try files.createDirectory(at:destination,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
                } else {
                    try Data(contentsOf:entry,options:.mappedIfSafe).write(to:destination,options:.withoutOverwriting)
                    let mode = (try files.attributesOfItem(atPath:entry.path)[.posixPermissions] as? NSNumber)?.intValue ?? 0
                    try files.setAttributes([.posixPermissions:mode & 0o111 == 0 ? 0o600 : 0o700],ofItemAtPath:destination.path)
                }
            }
        } catch { try? files.removeItem(at:helper);throw error }
    }
    public static func waitUntilReady(timeout: TimeInterval = 15, isRunning: () -> Bool,
                                      hasAcknowledged: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while isRunning(), Date() < deadline {
            if hasAcknowledged() { return }
            try await Task.sleep(nanoseconds:100_000_000)
        }
        throw UpdateError.invalid("The update helper could not start safely. Macbook Duo is still running; please try again or install with Finder.")
    }
}
