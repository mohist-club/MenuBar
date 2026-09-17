import Foundation

final class DeepLService: NSObject {
    static let shared = DeepLService()

    private var session: URLSession!

    private override init() {
        super.init()
        session = URLSession(configuration: .default)
    }

    /// DeepL 没有流式返回,一次性拿到完整译文。
    /// targetLanguageCode 明确指定这次要翻成哪种语言的代码(由调用方统一算好传进来)。
    /// 为了和 OpenAI 那边的调用方式保持一致,依然用 onToken/onComplete 这套回调:
    /// 成功时只调一次 onToken(完整译文),再调 onComplete(nil)。
    func translate(
        text: String,
        settings: TranslationSettings,
        targetLanguageCode: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Error?) -> Void
    ) {
        guard let apiKey = KeychainHelper.loadAPIKey(for: .deepl), !apiKey.isEmpty else {
            onComplete(NSError(domain: "Translation", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "尚未配置 DeepL API Key"]))
            return
        }

        // 提前拦截已知 DeepL 不支持的目标语言,避免发过去之后 DeepL 因为不认识这个语言
        // 而返回胡乱猜测的乱码结果(而不是一个明确的报错)。
        guard SupportedLanguage.deeplSupportedCodes.contains(targetLanguageCode) else {
            let langName = SupportedLanguage.label(for: targetLanguageCode)
            onComplete(NSError(domain: "Translation", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "DeepL 暂不支持「\(langName)」,建议切换到 OpenAI 试试(顶部切换引擎按钮)"
            ]))
            return
        }

        // DeepL 免费版的 Key 固定以 ":fx" 结尾,据此自动选对应的接口域名
        let isFreeKey = apiKey.hasSuffix(":fx")
        let host = isFreeKey ? "api-free.deepl.com" : "api.deepl.com"
        guard let url = URL(string: "https://\(host)/v2/translate") else {
            onComplete(NSError(domain: "Translation", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "无效的 DeepL 请求地址"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let body: [String: Any] = [
            "text": [text],
            "target_lang": targetLanguageCode
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    onComplete(error)
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard (200...299).contains(statusCode) else {
                    let message = Self.parseErrorMessage(data: data, statusCode: statusCode)
                    onComplete(NSError(domain: "Translation", code: statusCode,
                                        userInfo: [NSLocalizedDescriptionKey: message]))
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let translations = json["translations"] as? [[String: Any]],
                      let translated = translations.first?["text"] as? String else {
                    onComplete(NSError(domain: "Translation", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "未收到翻译结果,请检查网络或 API Key"]))
                    return
                }

                // DeepL 遇到自己认不出的源语言(即使目标语言受支持)有时会猜错源语言,
                // 返回把某个字符疯狂重复几十次的"乱码"而不是明确报错。
                // 这里做一层兜底检测,发现这种异常就转成清晰的错误提示,而不是把乱码直接显示出来。
                if Self.looksLikeGarbage(translated) {
                    onComplete(NSError(domain: "Translation", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "DeepL 返回结果异常,可能不支持识别到的源语言,建议切换到 OpenAI 试试"
                    ]))
                    return
                }

                onToken(translated)
                onComplete(nil)
            }
        }
        task.resume()
    }

    /// 简单的乱码检测:同一个字符连续出现超过 8 次,基本可以断定不是正常翻译结果
    private static func looksLikeGarbage(_ text: String) -> Bool {
        var lastChar: Character?
        var runLength = 0
        for char in text where !char.isWhitespace {
            if char == lastChar {
                runLength += 1
                if runLength >= 8 { return true }
            } else {
                lastChar = char
                runLength = 1
            }
        }
        return false
    }

    private static func parseErrorMessage(data: Data?, statusCode: Int) -> String {
        if let data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            if statusCode == 403 {
                return "DeepL Key 无效或权限不足(403): \(message)"
            }
            if statusCode == 456 {
                return "DeepL 当月配额已用完(456): \(message)"
            }
            return message
        }
        return "DeepL 请求失败(HTTP \(statusCode))"
    }
}
