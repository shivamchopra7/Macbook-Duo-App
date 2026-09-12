import Foundation
import CryptoKit

public struct ReleaseUpdate: Sendable {
    public static let repository = "shivamchopra7/Macbook-Duo-App"
    public static var archiveName: String { archiveName(for:.current) }
    public static let checksumName = "Macbook-Duo-SHA256SUMS.txt"
    public static let maximumArchiveBytes = 100 * 1024 * 1024
    public let tag: String
    public let version: ReleaseVersion
    public let archive: URL
    public let checksums: URL
    public let archiveSize: Int
    public var releasePage: URL { URL(string:"https://github.com/\(Self.repository)/releases/tag/\(tag)")! }

    public static func archiveName(for architecture: ReleaseArchitecture) -> String {
        architecture == .x86_64 ? "Macbook-Duo-Intel.zip" : "Macbook-Duo-mac.zip"
    }

    public static func newerRelease(data: Data, installed: String,
                                    architecture: ReleaseArchitecture = .current) throws -> Self? {
        guard let current = ReleaseVersion(installed) else { throw UpdateError.invalid("This app has an unknown version. Download the latest installer from GitHub.") }
        let release = try JSONDecoder().decode(GitHubRelease.self,from:data)
        guard !release.draft, !release.prerelease,
              let version = ReleaseVersion(release.tag_name) else {
            throw UpdateError.invalid("GitHub did not return a stable Macbook Duo release.")
        }
        guard version > current else { return nil }
        func asset(_ name: String, maximum: Int) throws -> GitHubRelease.Asset {
            let matches = release.assets.filter { $0.name == name }
            guard matches.count == 1, let value = matches.first, value.size > 0, value.size <= maximum,
                  let url = URL(string:value.browser_download_url),
                  url.absoluteString == "https://github.com/\(repository)/releases/download/\(release.tag_name)/\(name)" else {
                throw UpdateError.invalid("The release is missing a valid Macbook Duo installer or checksum. Open the release on GitHub instead.")
            }
            return value
        }
        let zip = try asset(archiveName(for:architecture),maximum:maximumArchiveBytes)
        let sums = try asset(checksumName,maximum:16_384)
        return Self(tag:release.tag_name,version:version,archive:URL(string:zip.browser_download_url)!,
                    checksums:URL(string:sums.browser_download_url)!,archiveSize:zip.size)
    }

    public static func verifyChecksum(archive: Data, manifest: Data,
                                      architecture: ReleaseArchitecture = .current) throws {
        guard let text = String(data:manifest,encoding:.utf8) else { throw UpdateError.invalid("The release checksum could not be read.") }
        let matches = text.split(whereSeparator:\.isNewline).compactMap { line -> String? in
            let fields = line.split(whereSeparator:\.isWhitespace)
            let name = archiveName(for:architecture)
            guard fields.count == 2, fields[1] == Substring(name) || fields[1] == Substring("*"+name) else { return nil }
            return String(fields[0]).lowercased()
        }
        let digest = SHA256.hash(data:archive).map { String(format:"%02x",$0) }.joined()
        guard matches.count == 1, matches[0].count == 64, matches[0] == digest else {
            throw UpdateError.invalid("The download failed its SHA-256 integrity check. Nothing was installed.")
        }
    }
}
