import AppKit
import ApplicationServices

final class PermissionManager {
    static let shared = PermissionManager()
    private init() {}

    /// 当前是否已获得辅助功能权限(不弹系统提示)
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 显式请求时才显示系统权限弹窗。绝不能在启动、热键或翻译流程中
    /// 反复调用，否则 ad-hoc 签名更新后会造成连续授权提示。
    func ensureAccessibilityPermission(completion: @escaping (Bool) -> Void) {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            completion(true)
            return
        }

        // 未授权:展示引导弹窗,并轮询等待用户在系统设置里授权
        showGuidanceAlert()
        pollForPermission(completion: completion)
    }

    /// 启动时使用的静默检查：只读取系统当前状态，不显示提示或跳转设置。
    func checkAccessibilityPermission(completion: @escaping (Bool) -> Void) {
        completion(AXIsProcessTrusted())
    }

    private func showGuidanceAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "本应用需要「辅助功能」权限才能实现划词翻译和全局快捷键功能。\n请在弹出的系统设置页面中勾选本应用。"
        alert.addButton(withTitle: "前往系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            openSystemPreferencesAccessibilityPane()
        }
    }

    func openSystemPreferencesAccessibilityPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 每 2 秒检查一次权限状态,授权成功后回调(用户去系统设置勾选后无需重启 App)
    private func pollForPermission(completion: @escaping (Bool) -> Void) {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                completion(true)
            }
        }
    }
}
