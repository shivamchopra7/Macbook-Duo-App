import Foundation

/// The backup remains intact until the new app confirms it launched successfully.
public enum UpdateReplacement {
    public static func install(staged: URL, destination: URL, backup: URL,
                               launchAndConfirm: () throws -> Void) throws {
        let files = FileManager.default
        guard !files.fileExists(atPath:backup.path), files.fileExists(atPath:destination.path),
              files.fileExists(atPath:staged.path) else { throw UpdateError.invalid("The installation location changed. Please download the update manually.") }
        try files.moveItem(at:destination,to:backup)
        do {
            try files.moveItem(at:staged,to:destination)
            try launchAndConfirm()
        } catch {
            // Move the failed candidate back out before restoring the known working app.
            // Never delete the backup when a restoration fails.
            if files.fileExists(atPath:destination.path) { try files.moveItem(at:destination,to:staged) }
            try files.moveItem(at:backup,to:destination)
            throw error
        }
    }
}
