import AppKit

/// Permissions are tied to one canonical bundle path. Temporary copies from a
/// build folder, Downloads, or a mounted DMG create a separate TCC record.
enum InstallationManager {
    static let canonicalURL = URL(fileURLWithPath: "/Applications/MenuBarTranslator.app")

    static var isCanonicalInstallation: Bool {
        Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL == canonicalURL.standardizedFileURL
    }

    static func requireCanonicalInstallation() -> Bool {
        guard !isCanonicalInstallation else { return true }
        let alert = NSAlert()
        alert.messageText = "请从“应用程序”启动 MenuBar Translator"
        alert.informativeText = "当前运行的是：\n\(Bundle.main.bundleURL.path)\n\n为让辅助功能授权稳定生效，请将 App 拖到 /Applications 后，从该位置打开。"
        if FileManager.default.fileExists(atPath: canonicalURL.path) {
            alert.addButton(withTitle: "打开应用程序版本")
            alert.addButton(withTitle: "退出")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.openApplication(at: canonicalURL, configuration: .init())
            }
        } else {
            alert.addButton(withTitle: "退出")
        }
        return false
    }
}
