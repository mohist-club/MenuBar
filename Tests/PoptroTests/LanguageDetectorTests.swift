import XCTest
@testable import Poptro

final class LanguageDetectorTests: XCTestCase {

    func testDetectsChinese() {
        let code = LanguageDetector.detectedLanguageCode("这是一段完整的中文句子,用来测试语言识别。")
        XCTAssertEqual(code, "ZH")
    }

    func testDetectsEnglish() {
        let code = LanguageDetector.detectedLanguageCode("This is a complete English sentence for testing language detection.")
        XCTAssertEqual(code, "EN-US")
    }

    func testDetectsJapanese() {
        let code = LanguageDetector.detectedLanguageCode("これは言語検出をテストするための完全な日本語の文章です。")
        XCTAssertEqual(code, "JA")
    }

    func testDetectsKhmer() {
        // 之前的手写 Unicode 范围判断完全没覆盖高棉语,这个用例就是回归测试防止再退化
        let code = LanguageDetector.detectedLanguageCode("នេះគឺជាឧទាហរណ៍នៃភាសាខ្មែរសម្រាប់សាកល្បង")
        XCTAssertEqual(code, "KM")
    }

    func testEmptyTextReturnsEmptyCode() {
        XCTAssertEqual(LanguageDetector.detectedLanguageCode(""), "")
        XCTAssertEqual(LanguageDetector.detectedLanguageCode("   "), "")
    }

    func testDefaultTargetLanguageCode_ChineseInputGoesToSecondary() {
        var settings = TranslationSettings()
        settings.primaryLanguageCode = "ZH"
        settings.secondaryLanguageCode = "EN-US"

        let target = LanguageDetector.defaultTargetLanguageCode(
            for: "这是一段完整的中文句子,用来测试语言识别。", settings: settings
        )
        XCTAssertEqual(target, "EN-US")
    }

    func testDefaultTargetLanguageCode_AnyForeignLanguageGoesToPrimary() {
        var settings = TranslationSettings()
        settings.primaryLanguageCode = "ZH"
        settings.secondaryLanguageCode = "EN-US"

        // 英语(备语言本身)应该翻成主语言
        let englishTarget = LanguageDetector.defaultTargetLanguageCode(
            for: "This is a complete English sentence for testing.", settings: settings
        )
        XCTAssertEqual(englishTarget, "ZH")

        // 日语(既不是主也不是备)也应该翻成主语言,而不是英语
        let japaneseTarget = LanguageDetector.defaultTargetLanguageCode(
            for: "これは言語検出をテストするための完全な日本語の文章です。", settings: settings
        )
        XCTAssertEqual(japaneseTarget, "ZH")

        // 识别不出来的语言(比如高棉语目录里如果没有对应 primary/secondary)也应该按外语处理,翻成主语言
        let khmerTarget = LanguageDetector.defaultTargetLanguageCode(
            for: "នេះគឺជាឧទាហរណ៍នៃភាសាខ្មែរសម្រាប់សាកល្បង", settings: settings
        )
        XCTAssertEqual(khmerTarget, "ZH")
    }
}
