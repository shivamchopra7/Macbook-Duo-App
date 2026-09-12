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

    func testResourceBundleAndSourceKeyFallback() {
        XCTAssertEqual(L10n.text("missing.translation.key"),"missing.translation.key")
        XCTAssertFalse(L10n.format("Lid %.0f°",42.0).contains("%"))
        XCTAssertTrue(L10n.format("Lid %.0f°",42.0).contains("42"))
        XCTAssertFalse(L10n.format("Capture stopped: %@","example").contains("%@"))
    }
}
