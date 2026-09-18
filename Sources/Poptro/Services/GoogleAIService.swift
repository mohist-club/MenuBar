import Foundation

final class GoogleAIService {
    static let shared = GoogleAIService()
    private init() {}

    func translate(
        text: String,
        settings: TranslationSettings,
        targetLanguageCode: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Error?) -> Void
    ) {
        guard let apiKey = KeychainHelper.loadAPIKey(for: .google), !apiKey.isEmpty else {
            onComplete(Self.error("尚未配置 Google AI API Key"))
            return
        }

        let model = settings.googleModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty,
              var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            onComplete(Self.error("Google AI 模型名称无效"))
            return
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            onComplete(Self.error("Google AI 请求地址无效"))
            return
        }

        let target = SupportedLanguage.label(for: targetLanguageCode)
        let instruction = settings.customSystemPrompt + "\n\n本次翻译请求：必须翻译成「\(target)」，只输出译文。"
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": instruction]]],
            "contents": [["role": "user", "parts": [["text": text]]]],
            "generationConfig": ["temperature": 0.2]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error { onComplete(error); return }
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard (200...299).contains(status), let data else {
                    onComplete(Self.error(Self.apiError(from: data, status: status)))
                    return
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let content = candidates.first?["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]] else {
                    onComplete(Self.error("Google AI 未返回翻译结果"))
                    return
                }
                let translated = parts.compactMap { $0["text"] as? String }.joined()
                guard !translated.isEmpty else {
                    onComplete(Self.error("Google AI 未返回翻译结果"))
                    return
                }
                onToken(translated)
                onComplete(nil)
            }
        }.resume()
    }

    private static func apiError(from data: Data?, status: Int) -> String {
        if let data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return "Google AI 请求失败（HTTP \(status)）"
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "Translation", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
