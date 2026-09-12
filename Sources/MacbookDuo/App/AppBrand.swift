import AppKit

@MainActor enum AppBrand {
    static let mark: NSImage = {
        if let url = Bundle.main.url(forResource:"MacbookDuoMark",withExtension:"png"),
           let image = NSImage(contentsOf:url) { return image }
        return NSImage(systemSymbolName:"macbook",accessibilityDescription:"Macbook Duo") ?? NSImage()
    }()

    /// The full-color app icon, packaged as MacbookDuo.icns; the mark stands in during development.
    static let icon: NSImage = {
        if let url = Bundle.main.url(forResource:"MacbookDuo",withExtension:"icns"),
           let image = NSImage(contentsOf:url) { return image }
        return mark
    }()

    static var menuBarMark: NSImage {
        let image = mark.copy() as! NSImage
        image.size = NSSize(width:22,height:22)
        image.isTemplate = true
        image.accessibilityDescription = "Macbook Duo"
        return image
    }
}
