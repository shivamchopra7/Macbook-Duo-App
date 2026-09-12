import Foundation

/// Stable releases only. Numeric components avoid lexicographic version mistakes.
public struct ReleaseVersion: Comparable, Sendable {
    public let components: [Int]
    public init?(_ value: String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = text.split(separator:".",omittingEmptySubsequences:false)
        guard (2...4).contains(parts.count), text.count < 50,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        components = numbers + Array(repeating:0,count:4-numbers.count)
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

public struct GitHubRelease: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public let name: String
        public let browser_download_url: String
        public let size: Int
    }
    public let tag_name: String
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]
}

public enum ReleaseArchitecture: Sendable, Equatable {
    case arm64, x86_64

    public static var current: Self {
        #if arch(arm64)
        .arm64
        #elseif arch(x86_64)
        .x86_64
        #else
        #error("Macbook Duo supports only arm64 and x86_64.")
        #endif
    }

    public init?(archiveName: String) {
        switch archiveName {
        case ReleaseUpdate.archiveName(for:.arm64): self = .arm64
        case ReleaseUpdate.archiveName(for:.x86_64): self = .x86_64
        default: return nil
        }
    }
}
