import AppKit
import ImageIO

/// Bundled files that both build flavours load the same way: from the SwiftPM
/// resource bundle when it is packaged next to the executable, otherwise from
/// the main bundle, where the Xcode build puts resources directly.
enum AppResources {
    static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource:"MacbookDuo_MacbookDuo",withExtension:"bundle"),
           let packaged = Bundle(url:url) { return packaged }
        return Bundle.main
    }()

    /// The wallpaper drawn behind the preview artwork, or nil when the file is
    /// missing, in which case the artwork falls back to its painted gradient.
    static var previewWallpaper: CGImage? {
        guard let url = bundle.url(forResource:"PreviewWallpaper",withExtension:"jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL,nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source,0,nil)
    }
}
