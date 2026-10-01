import Foundation
import XCTest
@testable import MacbookDuo

/// The app presents itself as "Foldbook" everywhere the user can read the name.
final class AppBrandTests: XCTestCase {
    @MainActor func testEachDistributionHasAppName() {
        XCTAssertEqual(AppBrand.storeName, "Foldbook")
        XCTAssertEqual(AppBrand.directDownloadName, "Foldbook")
        XCTAssertEqual(AppBrand.name, "Foldbook")
    }

    func testAppNameIsNotEmpty() {
        XCTAssertFalse(AppBrand.name.isEmpty)
        XCTAssertFalse(AppBrand.storeName.isEmpty)
        XCTAssertFalse(AppBrand.directDownloadName.isEmpty)
    }

    func testBrandedTextIsBuiltFromTheCurrentName() {
        XCTAssertEqual(AppBrand.text("Quit %@"), "Quit \(AppBrand.name)")
        XCTAssertEqual(AppBrand.text("Enable %@"), "Enable \(AppBrand.name)")
        XCTAssertFalse(AppBrand.text("Open %@…").contains("%@"))
    }
}
