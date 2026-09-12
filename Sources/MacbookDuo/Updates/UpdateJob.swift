// Direct-download builds only. App Store builds compile AppUpdater+AppStore.swift instead.
#if !APPSTORE
import Foundation
import FoldCore

struct UpdateJob: Codable, Sendable {
    let token: String
    let destination: String
    let staging: String
    let version: String
    let parentPID: Int32
    let executableHash: String
    let installAfterExit: Bool
    var folder: URL { UpdateInstallation.cache.appendingPathComponent(token,isDirectory:true) }
    var identity: UpdateBundleIdentity? {
        ReleaseVersion(version).map { UpdateBundleIdentity(bundleIdentifier:"com.shivamchopra.macbookduo",version:$0,executableHash:executableHash) }
    }
}

struct UpdateHelperReady: Codable {
    let processID: Int32
    let executableHash: String
}
#endif
