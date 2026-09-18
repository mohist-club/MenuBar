import Foundation

struct ProviderBenchmarkResult: Codable, Equatable {
    let provider: TranslationProvider
    let model: String
    let testedAt: Date
    let firstTokenSeconds: Double?
    let totalSeconds: Double?
    let charactersPerSecond: Double?
    let errorMessage: String?

    var isSuccessful: Bool { errorMessage == nil && totalSeconds != nil }
}

enum ProviderBenchmarkStore {
    private static let filename = "provider_benchmarks.json"

    static func load() -> [TranslationProvider: ProviderBenchmarkResult] {
        let values = LocalStore.load([ProviderBenchmarkResult].self, filename: filename, default: [])
        return Dictionary(uniqueKeysWithValues: values.map { ($0.provider, $0) })
    }

    static func save(_ result: ProviderBenchmarkResult) {
        var values = load()
        values[result.provider] = result
        LocalStore.save(Array(values.values), filename: filename)
    }
}

enum ProviderBenchmarkService {
    private static let sampleText = "Poptro turns selected text into a clear and natural translation with one keyboard shortcut."

    static func run(
        provider: TranslationProvider,
        settings: TranslationSettings,
        completion: @escaping (ProviderBenchmarkResult) -> Void
    ) {
        let startedAt = CFAbsoluteTimeGetCurrent()
        var firstTokenAt: CFAbsoluteTime?
        var translatedText = ""

        let onToken: (String) -> Void = { token in
            if firstTokenAt == nil { firstTokenAt = CFAbsoluteTimeGetCurrent() }
            translatedText += token
        }
        let onComplete: (Error?) -> Void = { error in
            let finishedAt = CFAbsoluteTimeGetCurrent()
            let total = max(finishedAt - startedAt, 0.001)
            let result = ProviderBenchmarkResult(
                provider: provider,
                model: settings.model(for: provider),
                testedAt: Date(),
                firstTokenSeconds: firstTokenAt.map { max($0 - startedAt, 0) },
                totalSeconds: error == nil ? total : nil,
                charactersPerSecond: error == nil ? Double(translatedText.count) / total : nil,
                errorMessage: error?.localizedDescription
            )
            ProviderBenchmarkStore.save(result)
            completion(result)
        }

        switch provider {
        case .zhipu, .openai, .groq:
            TranslationService.shared.translateStreaming(
                text: sampleText,
                settings: settings,
                provider: provider,
                targetLanguageCode: "ZH",
                onToken: onToken,
                onComplete: onComplete
            )
        case .deepl:
            DeepLService.shared.translate(
                text: sampleText,
                settings: settings,
                targetLanguageCode: "ZH",
                onToken: onToken,
                onComplete: onComplete
            )
        case .google:
            GoogleAIService.shared.translate(
                text: sampleText,
                settings: settings,
                targetLanguageCode: "ZH",
                onToken: onToken,
                onComplete: onComplete
            )
        case .ollama:
            OllamaService.shared.translateStreaming(
                text: sampleText,
                settings: settings,
                targetLanguageCode: "ZH",
                onToken: onToken,
                onComplete: onComplete
            )
        }
    }
}
