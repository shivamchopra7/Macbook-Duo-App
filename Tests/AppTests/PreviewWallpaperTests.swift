import Foundation
import ImageIO
import XCTest
@testable import MacbookDuo

/// The preview artwork inside the app, the website's demo frames and the store
/// screenshots all draw the bundled wallpaper, so it must be present, decodable
/// and close to the 1440×936 artwork aspect it is scaled to fill.
final class PreviewWallpaperTests: XCTestCase {
    private var wallpaper: URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/MacbookDuo/Resources/PreviewWallpaper.jpg")
    }

    func testWallpaperIsBundledAndFitsTheArtwork() throws {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(wallpaper as CFURL, nil), "PreviewWallpaper.jpg is missing")
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertGreaterThanOrEqual(image.width, 1440, "the wallpaper would be upscaled")
        XCTAssertEqual(Double(image.width)/Double(image.height), 1440.0/936.0, accuracy: 0.08, "the wallpaper aspect is far from the artwork's")
        let bytes = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: wallpaper.path)[.size] as? Int)
        XCTAssertLessThan(bytes, 1_000_000, "keep the bundled wallpaper under a megabyte")
    }

    func testResourceBundleResolves() {
        XCTAssertNotNil(AppResources.bundle.bundleURL)
    }
}
