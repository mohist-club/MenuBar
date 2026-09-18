import XCTest
@testable import Poptro

final class TranslationSettingsTests: XCTestCase {

    func testDecodingMissingFieldsFallsBackToDefaults() throws {
        // 模拟一份"很旧"的配置文件,只有最早期就有的字段,缺了后来加的所有字段
        let oldJSON = """
        { "provider": "openai" }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: oldJSON)

        // 缺失的字段应该用默认值填上,而不是让整体解码失败
        XCTAssertEqual(decoded.provider, .openai)
        XCTAssertTrue(decoded.configuredProviders.isEmpty)
        XCTAssertEqual(decoded.model, "gpt-4.1-mini")
        XCTAssertEqual(decoded.zhipuModel, "glm-4-flash-250414")
        XCTAssertEqual(decoded.groqModel, "qwen/qwen3.8-27b")
        XCTAssertEqual(decoded.googleModel, "gemini-3.5-flash-lite")
        XCTAssertEqual(decoded.primaryLanguageCode, "ZH")
        XCTAssertEqual(decoded.secondaryLanguageCode, "EN-US")
        XCTAssertEqual(decoded.panelAppearanceMode, .light)
        XCTAssertFalse(decoded.customSystemPrompt.isEmpty)
    }

    func testDecodingUnknownExtraFieldsDoesNotFail() throws {
        // 模拟"未来版本"存的文件里多了几个这个版本还不认识的字段,不应该导致解码失败
        let futureJSON = """
        {
            "provider": "deepl",
            "model": "gpt-4.1-mini",
            "primaryLanguageCode": "ZH",
            "secondaryLanguageCode": "JA",
            "panelAppearanceMode": "dark",
            "customSystemPrompt": "test prompt",
            "someFieldFromTheFuture": "should be ignored"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: futureJSON)
        XCTAssertEqual(decoded.provider, .deepl)
        XCTAssertEqual(decoded.secondaryLanguageCode, "JA")
        XCTAssertEqual(decoded.panelAppearanceMode, .dark)
    }

    func testEncodeDecodeRoundTrip() throws {
        var settings = TranslationSettings()
        settings.provider = .deepl
        settings.primaryLanguageCode = "ZH"
        settings.secondaryLanguageCode = "FR"
        settings.panelAppearanceMode = .system
        settings.groqModel = "llama-3.3-70b-versatile"
        settings.googleModel = "gemini-2.5-flash-lite"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: data)

        XCTAssertEqual(decoded.provider, .deepl)
        XCTAssertEqual(decoded.secondaryLanguageCode, "FR")
        XCTAssertEqual(decoded.panelAppearanceMode, .system)
        XCTAssertEqual(decoded.groqModel, "llama-3.3-70b-versatile")
        XCTAssertEqual(decoded.googleModel, "gemini-2.5-flash-lite")
    }

    func testProviderModelRoutingAndDiscoveryCapabilities() {
        var settings = TranslationSettings()
        settings.setModel("groq-test", for: .groq)
        settings.setModel("google-test", for: .google)

        XCTAssertEqual(settings.model(for: .groq), "groq-test")
        XCTAssertEqual(settings.model(for: .google), "google-test")
        XCTAssertTrue(TranslationProvider.groq.supportsRemoteModelDiscovery)
        XCTAssertTrue(TranslationProvider.google.supportsRemoteModelDiscovery)
        XCTAssertFalse(TranslationProvider.deepl.supportsRemoteModelDiscovery)
    }

    func testConfiguredProvidersRoundTrip() throws {
        var settings = TranslationSettings()
        settings.configuredProviders = [.deepl, .ollama]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: data)

        XCTAssertEqual(decoded.configuredProviders, [.deepl, .ollama])
    }

    func testConfiguredLocalProviderRequiresSavedConfigurationValues() {
        var settings = TranslationSettings()
        settings.configuredProviders = [.ollama]

        XCTAssertEqual(settings.availableConfiguredProviders(), [.ollama])

        settings.ollamaModel = ""
        XCTAssertTrue(settings.availableConfiguredProviders().isEmpty)
    }

    func testBenchmarkResultRoundTrip() throws {
        let original = ProviderBenchmarkResult(
            provider: .groq,
            model: "qwen/qwen3.8-27b",
            testedAt: Date(timeIntervalSince1970: 1_800_000_000),
            firstTokenSeconds: 0.39,
            totalSeconds: 0.74,
            charactersPerSecond: 68,
            errorMessage: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderBenchmarkResult.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isSuccessful)
    }

    func testSupportedLanguageLabelLookup() {
        XCTAssertEqual(SupportedLanguage.label(for: "KM"), "高棉语")
        XCTAssertEqual(SupportedLanguage.label(for: "ZH"), "中文(简体)")
        // 找不到的代码,兜底直接原样返回代码本身,而不是崩溃或返回空字符串
        XCTAssertEqual(SupportedLanguage.label(for: "XX-UNKNOWN"), "XX-UNKNOWN")
    }

    func testDeepLSupportedCodesContainsCommonLanguages() {
        XCTAssertTrue(SupportedLanguage.deeplSupportedCodes.contains("ZH"))
        XCTAssertTrue(SupportedLanguage.deeplSupportedCodes.contains("EN-US"))
        // 高棉语目前不在 DeepL 支持范围内,这个用例是防止误加进去后 DeepLService 的拦截逻辑失效
        XCTAssertFalse(SupportedLanguage.deeplSupportedCodes.contains("KM"))
    }
}
