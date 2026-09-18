import Foundation

final class TranslationService: NSObject {
    static let shared = TranslationService()

    private var session: URLSession!
    private var onToken: ((String) -> Void)?
    private var onComplete: ((Error?) -> Void)?
    private var buffer = Data()

    /// 本次请求是否收到过任何有效译文片段
    private var didReceiveAnyToken = false
    /// 记录 HTTP 状态码。非 2xx 时说明接口报错,响应体不是 SSE 格式,需要单独解析
    private var httpStatusCode: Int?
    /// 非 2xx 情况下,原始响应体(用于解析错误信息)
    private var rawErrorBody = Data()

    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    /// 流式翻译。targetLanguageCode 明确指定这次要翻成哪种语言
    /// (由调用方根据文本内容自动判断,或者用户在弹窗里手动选了别的语言后传入),
    /// 不再依赖模型自己判断方向。
    /// onToken 在主线程逐段回调拼接文本,onComplete 结束时调用(带 error 或 nil)。
    func translateStreaming(
        text: String,
        settings: TranslationSettings,
        provider: TranslationProvider,
        targetLanguageCode: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Error?) -> Void
    ) {
        guard let endpoint = endpoint(for: provider) else {
            onComplete(NSError(domain: "Translation", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "当前服务不支持 OpenAI 兼容接口"])); return
        }
        guard let apiKey = KeychainHelper.loadAPIKey(for: provider), !apiKey.isEmpty else {
            onComplete(NSError(domain: "Translation", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "尚未配置 \(provider.displayName) API Key"]))
            return
        }

        self.onToken = onToken
        self.onComplete = onComplete
        self.buffer = Data()
        self.didReceiveAnyToken = false
        self.httpStatusCode = nil
        self.rawErrorBody = Data()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let targetLanguageName = SupportedLanguage.label(for: targetLanguageCode)
        // 用户在设置里自定义的 prompt 只负责"风格/格式"这些规则(不包含方向判断),
        // 方向在这里明确追加,是唯一的方向来源,不会再和 prompt 里的旧指令打架
        let systemPrompt = settings.customSystemPrompt + """


        本次翻译请求:无论原文是什么语言,必须翻译成「\(targetLanguageName)」,只输出译文。
        """

        var body: [String: Any] = [
            "model": settings.model(for: provider),
            "stream": true,
            // 低 temperature 让每次翻译用词更稳定、更忠实原文,减少"发挥"
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]
        // GPT-5 系列是推理模型,默认会先"思考"再作答,翻译这种任务不需要深度推理,
        // 把推理强度压到最低以保证响应速度(非 GPT-5 系列模型会忽略这个参数)
        if provider == .openai, settings.model.hasPrefix("gpt-5") {
            body["reasoning_effort"] = "minimal"
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = session.dataTask(with: request)
        task.resume()
    }

    private func endpoint(for provider: TranslationProvider) -> URL? {
        switch provider {
        case .zhipu:
            return URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")
        case .openai:
            return URL(string: "https://api.openai.com/v1/chat/completions")
        case .groq:
            return URL(string: "https://api.groq.com/openai/v1/chat/completions")
        case .deepl, .google, .ollama:
            return nil
        }
    }

    /// 尝试从非 2xx 的原始响应体里解析出可读的错误信息
    private func parseErrorMessage() -> String {
        if let json = try? JSONSerialization.jsonObject(with: rawErrorBody) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            return message
        }
        if let text = String(data: rawErrorBody, encoding: .utf8), !text.isEmpty {
            return text
        }
        return "请求失败(HTTP \(httpStatusCode ?? -1))"
    }
}

extension TranslationService: URLSessionDataDelegate {

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        httpStatusCode = (response as? HTTPURLResponse)?.statusCode
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 接口报错时(如 401/429/400),响应体是普通 JSON,不是 SSE,单独收集用于解析错误信息
        if let code = httpStatusCode, !(200...299).contains(code) {
            rawErrorBody.append(data)
            return
        }

        buffer.append(data)

        // SSE 格式: 每行 "data: {...}\n\n",按换行切分处理
        while let range = buffer.range(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)

            guard let line = String(data: lineData, encoding: .utf8),
                  line.hasPrefix("data: ") else { continue }

            let payload = String(line.dropFirst("data: ".count)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { continue }

            guard let jsonData = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }

            didReceiveAnyToken = true
            DispatchQueue.main.async { [weak self] in
                self?.onToken?(content)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let error {
                self.onComplete?(error)
                return
            }

            // HTTP 层面报错(比如 401/429),但网络请求本身没有 error
            if let code = self.httpStatusCode, !(200...299).contains(code) {
                let message = self.parseErrorMessage()
                self.onComplete?(NSError(domain: "Translation", code: code,
                                          userInfo: [NSLocalizedDescriptionKey: message]))
                return
            }

            // 请求"成功"了,但从头到尾没解析出任何译文片段——避免界面永远卡在"翻译中"
            if !self.didReceiveAnyToken {
                self.onComplete?(NSError(domain: "Translation", code: -1,
                                          userInfo: [NSLocalizedDescriptionKey: "未收到翻译结果,请检查网络或 API Key"]))
                return
            }

            self.onComplete?(nil)
        }
    }
}
