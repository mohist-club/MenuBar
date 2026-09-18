import AppKit
import Combine
import Foundation

enum InterfaceLanguage: String, Codable, CaseIterable, Identifiable {
    case chinese
    case english

    var id: String { rawValue }

    var nativeDisplayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var interfaceLanguage: InterfaceLanguage = .chinese
    var appearanceMode: PanelAppearanceMode = .system
    var glassEffectEnabled: Bool = true
    var automaticUpdateChecks: Bool = true

    /// User-facing transparency: 0 is more solid, 1 is more transparent.
    /// Text and controls remain fully opaque; only the native material changes.
    var glassTransparency: Double = 0.56

    private static let filename = "app_preferences.json"

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        interfaceLanguage = try container.decodeIfPresent(
            InterfaceLanguage.self,
            forKey: .interfaceLanguage
        ) ?? .chinese
        appearanceMode = try container.decodeIfPresent(
            PanelAppearanceMode.self,
            forKey: .appearanceMode
        ) ?? .system
        glassEffectEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .glassEffectEnabled
        ) ?? true
        automaticUpdateChecks = try container.decodeIfPresent(
            Bool.self,
            forKey: .automaticUpdateChecks
        ) ?? true
        glassTransparency = try container.decodeIfPresent(
            Double.self,
            forKey: .glassTransparency
        ) ?? 0.56
        glassTransparency = min(max(glassTransparency, 0.15), 0.85)
    }

    static func loadCurrent() -> AppPreferences {
        if let saved = LocalStore.load(
            AppPreferences?.self,
            filename: filename,
            default: nil
        ) {
            return saved
        }

        // One-time migration from the older translation-specific appearance field.
        var migrated = AppPreferences()
        migrated.appearanceMode = TranslationSettings.loadCurrent().panelAppearanceMode
        migrated.save()
        return migrated
    }

    func save() {
        LocalStore.save(self, filename: Self.filename)
    }
}

extension Notification.Name {
    static let poptroPreferencesDidChange = Notification.Name("PoptroPreferencesDidChange")
}

final class AppPreferencesStore: ObservableObject {
    static let shared = AppPreferencesStore()

    @Published var values: AppPreferences {
        didSet {
            values.save()
            NotificationCenter.default.post(name: .poptroPreferencesDidChange, object: nil)
        }
    }

    private init() {
        values = AppPreferences.loadCurrent()
    }
}

enum PoptroText {
    static func value(
        _ chinese: String,
        _ english: String,
        language: InterfaceLanguage
    ) -> String {
        language == .chinese ? chinese : english
    }
}

extension PanelAppearanceMode {
    func localizedName(language: InterfaceLanguage) -> String {
        switch self {
        case .light: return PoptroText.value("浅色", "Light", language: language)
        case .dark: return PoptroText.value("深色", "Dark", language: language)
        case .system: return PoptroText.value("跟随系统", "System", language: language)
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

extension TranslationProvider {
    func localizedDisplayName(language: InterfaceLanguage) -> String {
        switch self {
        case .zhipu:
            return PoptroText.value("智谱 GLM（默认）", "Zhipu GLM (Default)", language: language)
        case .openai:
            return PoptroText.value("OpenAI（GPT 系列）", "OpenAI (GPT models)", language: language)
        case .deepl:
            return "DeepL"
        case .groq:
            return "Groq"
        case .google:
            return "Google AI (Gemini)"
        case .ollama:
            return PoptroText.value("本地模型", "Local Model", language: language)
        }
    }
}

extension SupportedLanguage {
    private static let englishLabels: [String: String] = [
        "ZH": "Chinese (Simplified)", "EN-US": "English (US)", "EN-GB": "English (UK)",
        "JA": "Japanese", "KO": "Korean", "FR": "French", "DE": "German", "ES": "Spanish",
        "IT": "Italian", "PT-BR": "Portuguese (Brazil)", "PT-PT": "Portuguese (Portugal)",
        "RU": "Russian", "NL": "Dutch", "PL": "Polish", "TR": "Turkish", "VI": "Vietnamese",
        "TH": "Thai", "ID": "Indonesian", "MS": "Malay", "AR": "Arabic", "HE": "Hebrew",
        "HI": "Hindi", "BN": "Bengali", "UR": "Urdu", "FA": "Persian", "EL": "Greek",
        "SV": "Swedish", "DA": "Danish", "FI": "Finnish", "NB": "Norwegian", "CS": "Czech",
        "SK": "Slovak", "HU": "Hungarian", "RO": "Romanian", "BG": "Bulgarian",
        "UK": "Ukrainian", "HR": "Croatian", "SL": "Slovenian", "ET": "Estonian",
        "LV": "Latvian", "LT": "Lithuanian", "CA": "Catalan", "IS": "Icelandic",
        "KM": "Khmer", "MY": "Burmese", "LO": "Lao", "MN": "Mongolian", "TA": "Tamil",
        "TE": "Telugu", "KN": "Kannada", "ML": "Malayalam", "MR": "Marathi",
        "GU": "Gujarati", "PA": "Punjabi", "SI": "Sinhala", "BO": "Tibetan",
        "HY": "Armenian", "KA": "Georgian", "AM": "Amharic", "KK": "Kazakh"
    ]

    static func localizedLabel(for code: String, language: InterfaceLanguage) -> String {
        if language == .english {
            return englishLabels[code] ?? code
        }
        return label(for: code)
    }
}
