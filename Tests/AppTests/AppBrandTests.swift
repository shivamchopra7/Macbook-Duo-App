import Foundation
import XCTest
@testable import MacbookDuo

/// The Mac App Store build presents itself as "Macbook Fold" everywhere the
/// user can read the name, while the direct download keeps "Macbook Duo".
final class AppBrandTests: XCTestCase {
    @MainActor func testEachDistributionHasItsOwnName() {
        XCTAssertEqual(AppBrand.storeName, "Macbook Fold")
        XCTAssertEqual(AppBrand.directDownloadName, "Macbook Duo")
        XCTAssertEqual(AppBrand.name, AppUpdater.isAppStoreBuild ? AppBrand.storeName : AppBrand.directDownloadName)
    }

    func testTheTwoNamesDiffer() {
        XCTAssertNotEqual(AppBrand.storeName, AppBrand.directDownloadName)
        XCTAssertFalse(AppBrand.storeName.isEmpty)
    }

    func testBrandedTextIsBuiltFromTheCurrentName() {
        XCTAssertEqual(AppBrand.text("Quit %@"), "Quit \(AppBrand.name)")
        XCTAssertEqual(AppBrand.text("Enable %@"), "Enable \(AppBrand.name)")
        XCTAssertFalse(AppBrand.text("Open %@…").contains("%@"))
    }
}
