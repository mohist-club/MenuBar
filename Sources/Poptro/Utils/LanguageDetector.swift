import Foundation
import NaturalLanguage

enum LanguageDetector {
    /// 用苹果系统自带的 NaturalLanguage 框架识别文本的语言,覆盖 50+ 种语言,
    /// 比手写 Unicode 范围判断精确得多(能区分拉丁字母语系里的英/法/德/西/越南语等,
    /// 也能识别中日韩之外的高棉语、泰语、阿拉伯语、印地语等)。
    /// 返回 SupportedLanguage 目录里的代码;识别不出来或者目录里没有对应条目时返回空字符串。
    static func detectedLanguageCode(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage else { return "" }
        return mapToSupportedCode(language)
    }

    /// 是否识别出了具体语言(能在 SupportedLanguage 目录里找到对应条目)
    static func hasRecognizedLanguage(_ text: String) -> Bool {
        !detectedLanguageCode(text).isEmpty
    }

    /// 根据文本内容自动判断默认目标语言代码:
    /// 识别出的语言正好是配置的"主语言"(比如中文)-> 翻成"备语言";
    /// 其它任何语言(不管识别出的是哪种,或者没识别出来)-> 一律翻成"主语言"。
    /// 这样规则不依赖穷举语言列表,天然覆盖"识别不出来的语言也按外语处理"这种情况。
    static func defaultTargetLanguageCode(for text: String, settings: TranslationSettings) -> String {
        let detected = detectedLanguageCode(text)
        if !detected.isEmpty && detected == settings.primaryLanguageCode {
            return settings.secondaryLanguageCode
        }
        return settings.primaryLanguageCode
    }

    // NLLanguage(苹果的语言标识)-> SupportedLanguage 目录代码 的映射表
    private static func mapToSupportedCode(_ language: NLLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese: return "ZH"
        case .english: return "EN-US"
        case .japanese: return "JA"
        case .korean: return "KO"
        case .french: return "FR"
        case .german: return "DE"
        case .spanish: return "ES"
        case .italian: return "IT"
        case .portuguese: return "PT-BR"
        case .russian: return "RU"
        case .dutch: return "NL"
        case .polish: return "PL"
        case .turkish: return "TR"
        case .vietnamese: return "VI"
        case .thai: return "TH"
        case .indonesian: return "ID"
        case .malay: return "MS"
        case .arabic: return "AR"
        case .hebrew: return "HE"
        case .hindi: return "HI"
        case .bengali: return "BN"
        case .urdu: return "UR"
        case .persian: return "FA"
        case .greek: return "EL"
        case .swedish: return "SV"
        case .danish: return "DA"
        case .finnish: return "FI"
        case .norwegian: return "NB"
        case .czech: return "CS"
        case .slovak: return "SK"
        case .hungarian: return "HU"
        case .romanian: return "RO"
        case .bulgarian: return "BG"
        case .ukrainian: return "UK"
        case .croatian: return "HR"
        case .catalan: return "CA"
        case .icelandic: return "IS"
        case .khmer: return "KM"
        case .burmese: return "MY"
        case .lao: return "LO"
        case .mongolian: return "MN"
        case .tamil: return "TA"
        case .telugu: return "TE"
        case .kannada: return "KN"
        case .malayalam: return "ML"
        case .marathi: return "MR"
        case .gujarati: return "GU"
        case .punjabi: return "PA"
        case .sinhalese: return "SI"
        case .tibetan: return "BO"
        case .armenian: return "HY"
        case .georgian: return "KA"
        case .amharic: return "AM"
        case .kazakh: return "KK"
        default: return "" // 识别到了但目录里没有对应条目,交给上层按"未识别"兜底处理
        }
    }
}
