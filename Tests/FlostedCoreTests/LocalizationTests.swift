import XCTest
import Foundation

final class LocalizationTests: XCTestCase {
    private var project: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private let languages = ["de", "en"]

    private func directory(_ language: String) -> URL {
        project.appendingPathComponent("Resources/\(language).lproj")
    }

    private func translations(_ language: String) throws -> [String: String] {
        let data = try Data(contentsOf: directory(language).appendingPathComponent("Localizable.strings"))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            as? [String: String], "\(language): ungültige Sprachdatei")
    }

    func testBothLanguagesParseAndContainTheSameNonemptyKeys() throws {
        let german = try translations("de"), english = try translations("en")
        XCTAssertFalse(german.isEmpty)
        XCTAssertEqual(Set(german.keys), Set(english.keys))
        for language in languages {
            for (key, value) in try translations(language) {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               "\(language): \(key) ist leer")
                XCTAssertNotEqual(value, key, "\(language): \(key) enthält nur den Schlüssel")
            }
        }
    }

    func testFoundationResolvesEveryTranslation() throws {
        // Exercise the real .strings loader as well as the property-list parser.
        // Choosing the lproj directly avoids changing the system language.
        for language in languages {
            let bundle = try XCTUnwrap(Bundle(path: directory(language).path))
            for (key, value) in try translations(language) {
                XCTAssertEqual(bundle.localizedString(forKey: key, value: "MISSING", table: nil), value,
                               "\(language): \(key) wird nicht aufgelöst")
            }
            let ready = bundle.localizedString(forKey: "status.ready", value: nil, table: nil)
            XCTAssertTrue(String(format: ready, "⇧").contains("⇧"))
            let page = bundle.localizedString(forKey: "editor.pageOf", value: nil, table: nil)
            let formatted = String(format: page, 2, 5)
            XCTAssertTrue(formatted.contains("2"))
            XCTAssertTrue(formatted.contains("5"))
            XCTAssertFalse(formatted.contains("%"))
        }
    }

    func testFormatArgumentsAgreeBetweenLanguages() throws {
        let german = try translations("de"), english = try translations("en")
        for key in german.keys.sorted() {
            let other = try XCTUnwrap(english[key], key)
            XCTAssertEqual(try arguments(german[key]!), try arguments(other), key)
        }
    }

    private func arguments(_ format: String) throws -> [Int: String] {
        let text = format.replacingOccurrences(of: "%%", with: "") as NSString
        let pattern = try NSRegularExpression(pattern: #"%(?:(\d+)\$)?(@|d)"#)
        let range = NSRange(location: 0, length: text.length)
        XCTAssertFalse(pattern.stringByReplacingMatches(in: text as String, range: range, withTemplate: "")
            .contains("%"), "Unbekannter Formatplatzhalter: \(format)")
        var result: [Int: String] = [:]
        var next = 1
        for match in pattern.matches(in: text as String, range: range) {
            let explicit = match.range(at: 1)
            let position = explicit.location == NSNotFound ? next : Int(text.substring(with: explicit))!
            let type = text.substring(with: match.range(at: 2))
            if let existing = result[position] { XCTAssertEqual(existing, type, format) }
            result[position] = type
            next += 1
        }
        return result
    }

    func testLocalizationKeysUsedInSourceExistInBothLanguages() throws {
        let german = try translations("de"), english = try translations("en")
        let namespaces = Set(german.keys.compactMap { $0.split(separator: ".").first.map(String.init) })
        let pattern = try NSRegularExpression(pattern: #""([a-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)+)""#)
        let files = try XCTUnwrap(FileManager.default.enumerator(
            at: project.appendingPathComponent("Sources"), includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8) as NSString
            for match in pattern.matches(in: source as String, range: NSRange(location: 0, length: source.length)) {
                let key = source.substring(with: match.range(at: 1))
                guard namespaces.contains(String(key.split(separator: ".")[0])) else { continue }
                XCTAssertNotNil(german[key], "de: \(key) in \(file.lastPathComponent)")
                XCTAssertNotNil(english[key], "en: \(key) in \(file.lastPathComponent)")
            }
        }
    }
}
