import Foundation
import XCTest
@testable import MacbookDuo

final class LocalizationTests: XCTestCase {
    private var resources: URL {
        URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/MacbookDuo/Resources")
    }

    private func strings(_ language: String, table: String = "Localizable") throws -> [String:String] {
        let data = try Data(contentsOf:resources.appendingPathComponent("\(language).lproj/\(table).strings"))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from:data,format:nil) as? [String:String])
    }

    func testTranslationsCoverEnglishKeysAndPreserveFormatArguments() throws {
        let english = try strings("en")
        let pattern = try NSRegularExpression(pattern:"%(?:[0-9]+\\$)?(?:[0-9]*\\.)?[0-9]*[@dfsu]")
        func placeholders(_ text: String) -> [String] {
            pattern.matches(in:text,range:NSRange(text.startIndex...,in:text)).map {
                String(text[Range($0.range,in:text)!])
            }
        }
        for language in ["en","zh-Hans","zh-Hant","ja"] {
            let translated = try strings(language)
            XCTAssertEqual(Set(translated.keys),Set(english.keys),language)
            for (key,value) in translated {
                XCTAssertFalse(value.isEmpty,"\(language): \(key)")
                XCTAssertEqual(placeholders(key),placeholders(value),"\(language): \(key)")
            }
            XCTAssertFalse(try XCTUnwrap(strings(language,table:"InfoPlist")["NSScreenCaptureUsageDescription"]).isEmpty)
        }
    }

    /// The store build is named "Macbook Fold" and the direct download "Macbook
    /// Duo", so text the store build shows must take the name as an argument
    /// instead of spelling "Macbook Duo" out. Only the self-updater, which is
    /// compiled out of the store build, may still name Macbook Duo directly.
    func testStoreFacingStringsTakeTheAppNameAsAnArgument() throws {
        let brandedKeys = ["Quit %@", "Pause %@", "Enable %@", "Open %@…", "%@ — your desktop follows your lid",
                           "Preview is ready. Enable %@ to use your desktop.",
                           "%@ needs an active, unmirrored built-in display.",
                           "Cannot safely exclude %@ from capture. Please reopen the app."]
        let updaterKeys = try strings("en").keys.filter { $0.contains("Macbook Duo") }
        for key in updaterKeys {
            XCTAssertTrue(key.contains("update") || key.contains("Update") || key.contains("release") || key.contains("is available") ||
                          key.contains("previous") || key.contains("Applications and open it") || key.contains("kept your"),
                          "\(key) is shown by the store build but hard-codes the direct-download name")
        }
        for language in ["en","zh-Hans","zh-Hant","ja"] {
            let translated = try strings(language)
            for key in brandedKeys {
                XCTAssertTrue(try XCTUnwrap(translated[key], "\(language): \(key)").contains("%@"), "\(language): \(key)")
            }
            let usage = try XCTUnwrap(strings(language,table:"InfoPlist")["NSScreenCaptureUsageDescription"])
            XCTAssertFalse(usage.contains("Macbook Duo"), "\(language): the permission prompt already shows the app name")
        }
    }

    /// Every literal key passed to L10n.text, L10n.format or AppBrand.text in
    /// the app sources must exist in the English table; a renamed key would
    /// otherwise fall back to the source text and lose every translation.
    func testEverySourceKeyExistsInTheEnglishTable() throws {
        let english = try strings("en")
        let sources = resources.deletingLastPathComponent()
        let pattern = try NSRegularExpression(pattern:#"(?:L10n\.text|L10n\.format|AppBrand\.text)\(\s*"((?:[^"\\]|\\.)*)""#)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at:sources,includingPropertiesForKeys:nil))
        var checked = 0
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf:file,encoding:.utf8)
            for match in pattern.matches(in:text,range:NSRange(text.startIndex...,in:text)) {
                let key = String(text[Range(match.range(at:1),in:text)!]).replacingOccurrences(of:"\\n",with:"\n")
                XCTAssertNotNil(english[key],"\(file.lastPathComponent): \(key)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked,100,"the source scan found too few keys to be trusted")
    }

    func testResourceBundleAndSourceKeyFallback() {
        XCTAssertEqual(L10n.text("missing.translation.key"),"missing.translation.key")
        XCTAssertFalse(L10n.format("Lid %.0f°",42.0).contains("%"))
        XCTAssertTrue(L10n.format("Lid %.0f°",42.0).contains("42"))
        XCTAssertFalse(L10n.format("Capture stopped: %@","example").contains("%@"))
    }
}
