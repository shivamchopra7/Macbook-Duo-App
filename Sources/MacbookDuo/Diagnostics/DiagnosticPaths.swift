import Foundation

/// Output locations for command-line diagnostics. LaunchServices can hand the
/// app arguments from any process (`open --args`), so a diagnostic must never
/// overwrite an existing file or write into Applications or system folders.
enum DiagnosticPaths {
    static let protectedPrefixes: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/Applications/", home + "/Applications/", "/System/", "/Library/", "/usr/", "/bin/", "/sbin/",
                "/private/etc/", "/etc/", "/private/var/db/", home + "/Library/"]
    }()

    static func isProtected(_ url: URL) -> Bool {
        let path = url.path
        return protectedPrefixes.contains { path.hasPrefix($0) } || path == FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// A directory that does not exist yet, outside protected locations.
    static func newDirectory(_ path: String) throws -> URL {
        let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        guard !path.isEmpty, !isProtected(url), !FileManager.default.fileExists(atPath: url.path),
              !isProtected(url.deletingLastPathComponent()) else {
            throw AppError.message("Choose a new output directory outside Applications, Library and system folders.")
        }
        return url
    }

    /// A file that does not exist yet, in an existing, unprotected directory.
    static func newFile(_ path: String) throws -> URL {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard !path.isEmpty, !isProtected(url), !FileManager.default.fileExists(atPath: url.path),
              FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AppError.message("Choose a new report file inside an existing folder outside Applications, Library and system folders.")
        }
        return url
    }
}
