import Foundation
import CryptoKit
import IOKit

/// Despite the historical name, this is now a local-only configuration store.
/// Ad-hoc signed builds cannot retain a stable Keychain access identity across
/// updates, which made macOS ask for the login-keychain password repeatedly.
/// API keys never leave this Mac and are saved only when the user clicks Save.
/// Values are AES-GCM encrypted with a key derived from this Mac's hardware
/// UUID, so the local preferences file does not contain a readable API key.
enum KeychainHelper {
    // Keep the legacy preference keys and encryption salt so existing API keys
    // remain readable after the public app name changes to Poptro 1.0.
    private static func localKey(for provider: TranslationProvider) -> String {
        switch provider {
        case .zhipu: return "com.menubartranslator.local.zhipu-api-key"
        case .openai: return "com.menubartranslator.local.openai-api-key"
        case .deepl: return "com.menubartranslator.local.deepl-api-key"
        case .groq: return "com.menubartranslator.local.groq-api-key"
        case .google: return "com.menubartranslator.local.google-api-key"
        case .ollama: return "com.menubartranslator.local.ollama-api-key"
        }
    }

    static func saveAPIKey(_ key: String, for provider: TranslationProvider) {
        guard let encrypted = encrypt(key) else { return }
        UserDefaults.standard.set(encrypted, forKey: localKey(for: provider))
    }

    static func loadAPIKey(for provider: TranslationProvider) -> String? {
        guard let stored = UserDefaults.standard.string(forKey: localKey(for: provider)) else { return nil }
        // Backwards compatible with the short-lived plaintext local format.
        return decrypt(stored) ?? stored
    }

    static func deleteAPIKey(for provider: TranslationProvider) {
        UserDefaults.standard.removeObject(forKey: localKey(for: provider))
    }

    static func migrateLegacyKeyIfNeeded() {}

    private static func encrypt(_ value: String) -> String? {
        guard let data = value.data(using: .utf8) else { return nil }
        do {
            let sealed = try AES.GCM.seal(data, using: encryptionKey)
            guard let combined = sealed.combined else { return nil }
            return "v1:" + combined.base64EncodedString()
        } catch { return nil }
    }

    private static func decrypt(_ value: String) -> String? {
        guard value.hasPrefix("v1:"),
              let data = Data(base64Encoded: String(value.dropFirst(3))) else { return nil }
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let clear = try AES.GCM.open(box, using: encryptionKey)
            return String(data: clear, encoding: .utf8)
        } catch { return nil }
    }

    private static var encryptionKey: SymmetricKey {
        let material = "com.menubartranslator.local.v1|\(machineIdentifier())"
        return SymmetricKey(data: SHA256.hash(data: Data(material.utf8)))
    }

    private static func machineIdentifier() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { if service != 0 { IOObjectRelease(service) } }
        guard service != 0,
              let value = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String else {
            return Host.current().localizedName ?? "unknown-mac"
        }
        return value
    }
}
