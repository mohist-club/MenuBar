import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.menubartranslator.app"

    private static func account(for provider: TranslationProvider) -> String {
        switch provider {
        case .openai: return "openai-api-key"
        case .deepl: return "deepl-api-key"
        case .ollama: return "ollama-api-key" // Ollama 是本地服务,不需要 Key,这里只是让 switch 穷尽
        }
    }

    static func saveAPIKey(_ key: String, for provider: TranslationProvider) {
        let data = Data(key.utf8)
        let acct = account(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acct
        ]
        // 先删除旧值再写入,保证幂等
        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        SecItemAdd(newItem as CFDictionary, nil)
    }

    static func loadAPIKey(for provider: TranslationProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey(for provider: TranslationProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider)
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - 兼容旧版本(历史上用过不同的 service 字符串存 Key,这里统一做一次性迁移)

    /// 按时间顺序列出历史上用过的 (service, account) 组合,新版本启动时依次尝试,
    /// 找到就迁移到当前的 service 字符串下,而不是让用户重新填一遍 Key。
    private static func legacySources(for provider: TranslationProvider) -> [(service: String, account: String)] {
        let acct = account(for: provider)
        switch provider {
        case .openai:
            return [
                ("com.wayne.menubartranslator", acct),       // 改成通用 Bundle ID 之前
                ("com.wayne.menubartranslator.openai", acct)  // 最早只存 OpenAI 一套时期
            ]
        case .deepl:
            return [
                ("com.wayne.menubartranslator", acct)
            ]
        case .ollama:
            return []
        }
    }

    /// 首次升级时,把旧版本存的 Key 迁移到当前 service 字符串下
    static func migrateLegacyKeyIfNeeded() {
        for provider in TranslationProvider.allCases {
            guard loadAPIKey(for: provider) == nil else { continue } // 新存储已经有值,不用迁移

            for source in legacySources(for: provider) {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: source.service,
                    kSecAttrAccount as String: source.account,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var result: AnyObject?
                guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                      let data = result as? Data,
                      let key = String(data: data, encoding: .utf8) else { continue }

                saveAPIKey(key, for: provider)
                break
            }
        }
    }
}
