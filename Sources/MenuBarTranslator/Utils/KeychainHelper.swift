import Foundation

/// Despite the historical name, this is now a local-only configuration store.
/// Ad-hoc signed builds cannot retain a stable Keychain access identity across
/// updates, which made macOS ask for the login-keychain password repeatedly.
/// API keys never leave this Mac and are saved only when the user clicks Save.
enum KeychainHelper {
    private static func localKey(for provider: TranslationProvider) -> String {
        switch provider {
        case .openai: return "com.menubartranslator.local.openai-api-key"
        case .deepl: return "com.menubartranslator.local.deepl-api-key"
        case .ollama: return "com.menubartranslator.local.ollama-api-key"
        }
    }

    static func saveAPIKey(_ key: String, for provider: TranslationProvider) {
        UserDefaults.standard.set(key, forKey: localKey(for: provider))
    }

    static func loadAPIKey(for provider: TranslationProvider) -> String? {
        UserDefaults.standard.string(forKey: localKey(for: provider))
    }

    static func deleteAPIKey(for provider: TranslationProvider) {
        UserDefaults.standard.removeObject(forKey: localKey(for: provider))
    }

    static func migrateLegacyKeyIfNeeded() {}
}
