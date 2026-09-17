import AVFoundation

final class AudioSpeaker {
    static let shared = AudioSpeaker()
    private let synthesizer = AVSpeechSynthesizer()
    private init() {}

    /// languageCode: SupportedLanguage 里的语言代码(如 "ZH"/"JA"/"EN-US"),
    /// 用来挑选发音更准确的系统语音,而不是只有中/英二选一
    func speak(_ text: String, languageCode: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceTag(for: languageCode))
        synthesizer.speak(utterance)
    }

    private static func voiceTag(for code: String) -> String {
        switch code {
        case "ZH": return "zh-CN"
        case "JA": return "ja-JP"
        case "KO": return "ko-KR"
        case "EN-GB": return "en-GB"
        case "FR": return "fr-FR"
        case "DE": return "de-DE"
        case "ES": return "es-ES"
        case "IT": return "it-IT"
        case "RU": return "ru-RU"
        case "PT-BR": return "pt-BR"
        case "VI": return "vi-VN"
        case "TH": return "th-TH"
        case "ID": return "id-ID"
        default: return "en-US" // 包含 EN-US 和其它未特别列出的情况
        }
    }
}
