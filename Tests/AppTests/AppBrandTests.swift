import Foundation
import XCTest
@testable import MacbookDuo

/// The Mac App Store listing may not carry an Apple trademark in its name
/// (App Review Guideline 5.2.5), so the store build presents itself as
/// "Lid Fold" everywhere the user can read the name, while the direct
/// download keeps "Macbook Duo".
final class AppBrandTests: XCTestCase {
    @MainActor func testEachDistributionHasItsOwnName() {
        XCTAssertEqual(AppBrand.storeName, "Lid Fold")
        XCTAssertEqual(AppBrand.directDownloadName, "Macbook Duo")
        XCTAssertEqual(AppBrand.name, AppUpdater.isAppStoreBuild ? AppBrand.storeName : AppBrand.directDownloadName)
    }

    func testStoreNameCarriesNoAppleTrademark() {
        for trademark in ["macbook", "mac ", "apple", "ios", "macos"] {
            XCTAssertFalse(AppBrand.storeName.lowercased().contains(trademark), trademark)
        }
    }

    func testBrandedTextIsBuiltFromTheCurrentName() {
        XCTAssertEqual(AppBrand.text("Quit %@"), "Quit \(AppBrand.name)")
        XCTAssertEqual(AppBrand.text("Enable %@"), "Enable \(AppBrand.name)")
        XCTAssertFalse(AppBrand.text("Open %@…").contains("%@"))
    }
}
