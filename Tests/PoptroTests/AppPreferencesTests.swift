import XCTest
@testable import Poptro

final class AppPreferencesTests: XCTestCase {
    func testMissingPreferenceFieldsUseStableDefaults() throws {
        let data = "{}".data(using: .utf8)!
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(preferences.interfaceLanguage, .chinese)
        XCTAssertEqual(preferences.appearanceMode, .system)
        XCTAssertTrue(preferences.glassEffectEnabled)
        XCTAssertTrue(preferences.automaticUpdateChecks)
        XCTAssertEqual(preferences.glassTransparency, 0.56, accuracy: 0.001)
    }

    func testTransparencyIsClampedWhenDecoding() throws {
        let data = """
        {"interfaceLanguage":"english","appearanceMode":"dark","glassTransparency":1.8}
        """.data(using: .utf8)!
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(preferences.interfaceLanguage, .english)
        XCTAssertEqual(preferences.appearanceMode, .dark)
        XCTAssertEqual(preferences.glassTransparency, 0.85, accuracy: 0.001)
    }

    func testLocalizedLanguageLabels() {
        XCTAssertEqual(
            SupportedLanguage.localizedLabel(for: "ZH", language: .english),
            "Chinese (Simplified)"
        )
        XCTAssertEqual(
            SupportedLanguage.localizedLabel(for: "ZH", language: .chinese),
            "中文(简体)"
        )
    }
}
