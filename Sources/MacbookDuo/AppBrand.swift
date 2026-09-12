import AppKit

@MainActor enum AppBrand {
    static let mark: NSImage = {
        if let url = Bundle.main.url(forResource:"MacbookDuoMark",withExtension:"png"),
           let image = NSImage(contentsOf:url) { return image }
        return NSImage(systemSymbolName:"macbook",accessibilityDescription:"Macbook Duo") ?? NSImage()
    }()

    static var menuBarMark: NSImage {
        let image = mark.copy() as! NSImage
        image.size = NSSize(width:22,height:22)
        image.isTemplate = true
        image.accessibilityDescription = "Macbook Duo"
        return image
    }
}
