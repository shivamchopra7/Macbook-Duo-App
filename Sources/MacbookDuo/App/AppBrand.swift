import AppKit

@MainActor enum AppBrand {
    /// The name the Mac App Store build shows. Apple's own product names may
    /// not appear in an App Store app name (App Review Guideline 5.2.5), so
    /// the store listing, bundle and interface all say "Lid Fold".
    nonisolated static let storeName = "Lid Fold"
    /// The name the direct download from GitHub shows.
    nonisolated static let directDownloadName = "Macbook Duo"
    /// The name of this build, chosen at compile time by the APPSTORE condition.
    nonisolated static let name: String = {
        #if APPSTORE
        storeName
        #else
        directDownloadName
        #endif
    }()

    /// A localized string whose single `%@` is the app name of this build.
    nonisolated static func text(_ key: String) -> String { L10n.format(key, name) }

    static let mark: NSImage = {
        if let url = Bundle.main.url(forResource:"MacbookDuoMark",withExtension:"png"),
           let image = NSImage(contentsOf:url) { return image }
        return NSImage(systemSymbolName:"macbook",accessibilityDescription:name) ?? NSImage()
    }()

    /// The full-color app icon, packaged as MacbookDuo.icns; the mark stands in during development.
    static let icon: NSImage = {
        if let url = Bundle.main.url(forResource:"MacbookDuo",withExtension:"icns"),
           let image = NSImage(contentsOf:url) { return image }
        // Asset-catalog builds (App Store) carry the icon in Assets.car instead.
        if Bundle.main.url(forResource:"Assets",withExtension:"car") != nil { return NSApplication.shared.applicationIconImage }
        return mark
    }()

    static var menuBarMark: NSImage {
        let image = mark.copy() as! NSImage
        image.size = NSSize(width:22,height:22)
        image.isTemplate = true
        image.accessibilityDescription = name
        return image
    }
}
