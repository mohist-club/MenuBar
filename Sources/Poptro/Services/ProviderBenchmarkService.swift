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
    private static let retryDelay: TimeInterval = 0.65

    static func run(
        provider: TranslationProvider,
        settings: TranslationSettings,
        completion: @escaping (ProviderBenchmarkResult) -> Void
    ) {
        runAttempt(provider: provider, settings: settings, remainingRetries: 1, completion: completion)
    }

    private static func runAttempt(
        provider: TranslationProvider,
        settings: TranslationSettings,
        remainingRetries: Int,
        completion: @escaping (ProviderBenchmarkResult) -> Void
    ) {
        let startedAt = CFAbsoluteTimeGetCurrent()
        var firstTokenAt: CFAbsoluteTime?
        var translatedText = ""
        var didFinish = false

        let onToken: (String) -> Void = { token in
            if firstTokenAt == nil { firstTokenAt = CFAbsoluteTimeGetCurrent() }
            translatedText += token
        }
        let onComplete: (Error?) -> Void = { error in
            guard !didFinish else { return }
            didFinish = true

            if let error, remainingRetries > 0, isTransientNetworkError(error) {
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                    runAttempt(
                        provider: provider,
                        settings: settings,
                        remainingRetries: remainingRetries - 1,
                        completion: completion
                    )
                }
                return
            }

            let finishedAt = CFAbsoluteTimeGetCurrent()
            let total = max(finishedAt - startedAt, 0.001)
            let result = ProviderBenchmarkResult(
                provider: provider,
                model: settings.model(for: provider),
                testedAt: Date(),
                firstTokenSeconds: firstTokenAt.map { max($0 - startedAt, 0) },
                totalSeconds: error == nil ? total : nil,
                charactersPerSecond: error == nil ? Double(translatedText.count) / total : nil,
                errorMessage: error.map {
                    userFacingErrorMessage(
                        $0,
                        language: AppPreferencesStore.shared.values.interfaceLanguage
                    )
                }
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

    static func isTransientNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        let code = URLError.Code(rawValue: nsError.code)
        return [
            .networkConnectionLost,
            .timedOut,
            .cannotConnectToHost,
            .dnsLookupFailed
        ].contains(code)
    }

    static func userFacingErrorMessage(_ error: Error, language: InterfaceLanguage) -> String {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return error.localizedDescription
        }
        let code = URLError.Code(rawValue: nsError.code)

        switch code {
        case .networkConnectionLost, .timedOut, .cannotConnectToHost, .dnsLookupFailed:
            return PoptroText.value(
                "网络连接短暂中断，自动重试后仍未恢复，请稍后再试。",
                "The connection was interrupted and did not recover after an automatic retry. Please try again shortly.",
                language: language
            )
        case .notConnectedToInternet:
            return PoptroText.value(
                "当前没有可用的网络连接，请联网后重试。",
                "No internet connection is available. Reconnect and try again.",
                language: language
            )
        default:
            return error.localizedDescription
        }
    }
}
