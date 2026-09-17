import Foundation

final class OllamaService: NSObject {
    static let shared = OllamaService()

    private var session: URLSession!
    private var onToken: ((String) -> Void)?
    private var onComplete: ((Error?) -> Void)?
    private var buffer = Data()
    private var didReceiveAnyToken = false
    private var httpStatusCode: Int?

    private override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    /// Ollama 是本地服务,不需要 API Key。流式格式是 NDJSON(每行一个完整 JSON 对象),
    /// 和 OpenAI 的 SSE("data: {...}")不一样,单独解析。
    func translateStreaming(
        text: String,
        settings: TranslationSettings,
        targetLanguageCode: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Error?) -> Void
    ) {
        guard let baseURL = URL(string: settings.ollamaBaseURL),
              let url = URL(string: "/api/chat", relativeTo: baseURL) else {
            onComplete(NSError(domain: "Translation", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Ollama 地址无效: \(settings.ollamaBaseURL)"]))
            return
        }

        self.onToken = onToken
        self.onComplete = onComplete
        self.buffer = Data()
        self.didReceiveAnyToken = false
        self.httpStatusCode = nil

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 本地跑模型有时候第一次加载模型会比较慢,给长一点的超时
        request.timeoutInterval = 60

        let targetLanguageName = SupportedLanguage.label(for: targetLanguageCode)
        let systemPrompt = settings.customSystemPrompt + """


        本次翻译请求:无论原文是什么语言,必须翻译成「\(targetLanguageName)」,只输出译文。
        """

        let body: [String: Any] = [
            "model": settings.ollamaModel,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = session.dataTask(with: request)
        task.resume()
    }
}

extension OllamaService: URLSessionDataDelegate {

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        httpStatusCode = (response as? HTTPURLResponse)?.statusCode
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)

        // NDJSON: 每一行是一个独立的 JSON 对象,按换行切分
        while let range = buffer.range(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            guard !lineData.isEmpty else { continue }

            guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            if let message = json["message"] as? [String: Any], let content = message["content"] as? String,
               !content.isEmpty {
                didReceiveAnyToken = true
                DispatchQueue.main.async { [weak self] in
                    self?.onToken?(content)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if let error {
                let nsError = error as NSError
                // Connection refused,基本可以断定是 Ollama 没启动
                if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCannotConnectToHost {
                    self.onComplete?(NSError(domain: "Translation", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "连接不上 Ollama,请确认已经在本机启动了 Ollama(ollama serve)"
                    ]))
                    return
                }
                self.onComplete?(error)
                return
            }

            if let code = self.httpStatusCode, !(200...299).contains(code) {
                self.onComplete?(NSError(domain: "Translation", code: code, userInfo: [
                    NSLocalizedDescriptionKey: "Ollama 请求失败(HTTP \(code)),模型「\(OllamaService.lastModelUsed)」是否已经 pull 下来了?"
                ]))
                return
            }

            if !self.didReceiveAnyToken {
                self.onComplete?(NSError(domain: "Translation", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "未收到翻译结果,请检查 Ollama 服务和模型是否正常"
                ]))
                return
            }

            self.onComplete?(nil)
        }
    }

    // 仅用于报错信息里提示模型名,不影响实际请求逻辑
    private static var lastModelUsed: String {
        TranslationSettings.loadCurrent().ollamaModel
    }
}
