import XCTest
import CoreGraphics
@testable import FLowmoCore

final class BrandMigrationTests: XCTestCase {
    func testSavedSignaturesAreCopiedOnceWithoutChangingTheOriginals() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let old = SignatureStore(folder: base.appendingPathComponent("Flosted/Signatures"))
        let canvas = try ImageTools.canvas(12, 8)
        let image = try XCTUnwrap(canvas.makeImage())
        try old.save(image, id: "existing")
        let original = try Data(contentsOf: old.folder.appendingPathComponent("existing.png"))

        let renamed = SignatureStore(applicationSupport: base)
        XCTAssertEqual(renamed.folder, base.appendingPathComponent("FLowmo/Signatures", isDirectory: true))
        XCTAssertEqual(renamed.load()["existing"]?.width, 12)
        XCTAssertEqual(try Data(contentsOf: renamed.folder.appendingPathComponent("existing.png")), original)
        XCTAssertEqual(try Data(contentsOf: old.folder.appendingPathComponent("existing.png")), original)

        renamed.remove(id: "existing")
        XCTAssertTrue(SignatureStore(applicationSupport: base).load().isEmpty,
                      "Gelöschte Signaturen dürfen nicht erneut importiert werden.")
        XCTAssertNotNil(old.load()["existing"])
    }

    func testExistingNewSignatureFolderIsNeverOverwritten() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let canvas = try ImageTools.canvas(12, 8)
        let image = try XCTUnwrap(canvas.makeImage())
        try SignatureStore(folder: base.appendingPathComponent("Flosted/Signatures")).save(image, id: "old")
        try SignatureStore(folder: base.appendingPathComponent("FLowmo/Signatures")).save(image, id: "new")
        XCTAssertEqual(Set(SignatureStore(applicationSupport: base).load().keys), ["new"])
    }
}
