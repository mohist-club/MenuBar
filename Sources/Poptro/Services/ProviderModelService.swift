import Foundation

enum ProviderModelServiceError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let name): return "请先填写 \(name) API Key"
        case .invalidResponse: return "服务返回了无法识别的模型列表"
        case .requestFailed(let message): return message
        }
    }
}

enum ProviderModelService {
    static func fallbackModels(for provider: TranslationProvider) -> [String] {
        switch provider {
        case .zhipu: return ["glm-4-flash-250414", "glm-4.7-flash"]
        case .openai: return ["gpt-4.1-mini", "gpt-4.1", "gpt-5-mini"]
        case .deepl: return []
        case .groq: return ["qwen/qwen3.8-27b", "openai/gpt-oss-20b", "openai/gpt-oss-120b"]
        case .google: return ["gemini-3.5-flash-lite", "gemini-2.5-flash-lite", "gemini-2.5-flash"]
        case .ollama: return ["qwen3:8b"]
        }
    }

    static func fetchModels(
        for provider: TranslationProvider,
        settings: TranslationSettings
    ) async throws -> [String] {
        switch provider {
        case .deepl:
            return []
        case .ollama:
            return try await fetchOllamaModels(baseURL: settings.ollamaBaseURL)
        case .google:
            return try await fetchGoogleModels(apiKey: try apiKey(for: provider))
        case .zhipu, .openai, .groq:
            return try await fetchOpenAICompatibleModels(
                provider: provider,
                apiKey: try apiKey(for: provider)
            )
        }
    }

    static func testConnection(
        for provider: TranslationProvider,
        settings: TranslationSettings
    ) async throws {
        if provider == .deepl {
            let key = try apiKey(for: .deepl)
            let host = key.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
            var request = URLRequest(url: URL(string: "https://\(host)/v2/usage")!)
            request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
            _ = try await checkedData(for: request)
            return
        }
        _ = try await fetchModels(for: provider, settings: settings)
    }

    private static func apiKey(for provider: TranslationProvider) throws -> String {
        guard let key = KeychainHelper.loadAPIKey(for: provider), !key.isEmpty else {
            throw ProviderModelServiceError.missingAPIKey(provider.displayName)
        }
        return key
    }

    private static func fetchOpenAICompatibleModels(
        provider: TranslationProvider,
        apiKey: String
    ) async throws -> [String] {
        let urlString: String
        switch provider {
        case .zhipu: urlString = "https://open.bigmodel.cn/api/paas/v4/models"
        case .openai: urlString = "https://api.openai.com/v1/models"
        case .groq: urlString = "https://api.groq.com/openai/v1/models"
        default: throw ProviderModelServiceError.invalidResponse
        }
        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        let data = try await checkedData(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["data"] as? [[String: Any]] else {
            throw ProviderModelServiceError.invalidResponse
        }
        let models = values.compactMap { $0["id"] as? String }
            .filter { isTranslationModel($0, provider: provider) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        guard !models.isEmpty else { throw ProviderModelServiceError.invalidResponse }
        return models
    }

    private static func fetchGoogleModels(apiKey: String) async throws -> [String] {
        var all: [String] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")!
            var query = [URLQueryItem(name: "key", value: apiKey), URLQueryItem(name: "pageSize", value: "1000")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            let data = try await checkedData(for: URLRequest(url: components.url!))
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let values = json["models"] as? [[String: Any]] else {
                throw ProviderModelServiceError.invalidResponse
            }
            for value in values {
                let methods = value["supportedGenerationMethods"] as? [String] ?? []
                guard methods.contains("generateContent") else { continue }
                if let id = value["baseModelId"] as? String, !id.isEmpty {
                    all.append(id)
                } else if let name = value["name"] as? String {
                    all.append(name.replacingOccurrences(of: "models/", with: ""))
                }
            }
            pageToken = json["nextPageToken"] as? String
        } while pageToken != nil
        let result = Array(Set(all)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        guard !result.isEmpty else { throw ProviderModelServiceError.invalidResponse }
        return result
    }

    private static func fetchOllamaModels(baseURL: String) async throws -> [String] {
        guard let base = URL(string: baseURL), let url = URL(string: "/api/tags", relativeTo: base) else {
            throw ProviderModelServiceError.requestFailed("本地模型地址无效")
        }
        let data = try await checkedData(for: URLRequest(url: url))
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["models"] as? [[String: Any]] else {
            throw ProviderModelServiceError.invalidResponse
        }
        return values.compactMap { ($0["name"] as? String) ?? ($0["model"] as? String) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func checkedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ProviderModelServiceError.requestFailed(message)
            }
            throw ProviderModelServiceError.requestFailed("读取模型失败（HTTP \(status)）")
        }
        return data
    }

    private static func isTranslationModel(_ id: String, provider: TranslationProvider) -> Bool {
        let value = id.lowercased()
        let blocked = ["embed", "whisper", "tts", "audio", "guard", "moderation", "rerank", "ocr", "image", "vision", "realtime"]
        guard !blocked.contains(where: value.contains) else { return false }
        switch provider {
        case .zhipu: return value.hasPrefix("glm-")
        case .openai: return value.hasPrefix("gpt-") || value.hasPrefix("o1") || value.hasPrefix("o3") || value.hasPrefix("o4")
        case .groq: return true
        default: return true
        }
    }
}
