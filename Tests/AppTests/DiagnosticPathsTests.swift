import Foundation
import XCTest
@testable import MacbookDuo

final class DiagnosticPathsTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("MacbookDuo-paths-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: scratch) }

    func testNewDirectoryRejectsProtectedExistingAndTraversedLocations() throws {
        let fresh = scratch.appendingPathComponent("render").path
        XCTAssertEqual(try DiagnosticPaths.newDirectory(fresh).path, fresh)
        XCTAssertThrowsError(try DiagnosticPaths.newDirectory(scratch.path), "an existing directory is refused")
        XCTAssertThrowsError(try DiagnosticPaths.newDirectory("/Applications/Macbook Duo.app"))
        XCTAssertThrowsError(try DiagnosticPaths.newDirectory("/Library/LaunchDaemons/x"))
        let toRoot = String(repeating: "/..", count: scratch.pathComponents.count - 1)
        XCTAssertThrowsError(try DiagnosticPaths.newDirectory(scratch.path + toRoot + "/Applications/x"), "traversal into Applications is refused")
        XCTAssertThrowsError(try DiagnosticPaths.newDirectory(""))
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertThrowsError(try DiagnosticPaths.newDirectory(home.appendingPathComponent("Library/Preferences/x").path))
    }

    func testNewFileRequiresAnUnusedNameInAnExistingUnprotectedFolder() throws {
        let report = scratch.appendingPathComponent("overlay.json")
        XCTAssertEqual(try DiagnosticPaths.newFile(report.path), report)
        try Data("x".utf8).write(to: report)
        XCTAssertThrowsError(try DiagnosticPaths.newFile(report.path), "never overwrite")
        XCTAssertThrowsError(try DiagnosticPaths.newFile(scratch.appendingPathComponent("missing/overlay.json").path))
        XCTAssertThrowsError(try DiagnosticPaths.newFile("/Applications/overlay.json"))
        XCTAssertThrowsError(try DiagnosticPaths.newFile("/etc/overlay.json"))
    }
}
