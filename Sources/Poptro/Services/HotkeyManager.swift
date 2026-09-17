import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// 唯一的翻译快捷键:有划词就直接翻译,没划词就弹出空白输入框手动翻译。
    /// 默认 Option + D(类似 Bob 默认习惯,用户可在设置里改)
    static let translateSelection = Self("translateSelection", default: .init(.d, modifiers: [.option]))
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    private init() {}

    /// 注册"内置"功能的全局快捷键
    func registerAllHotkeys() {
        KeyboardShortcuts.onKeyUp(for: .translateSelection) {
            TranslationFlowCoordinator.shared.trigger()
        }
    }

    /// 为动态生成的 App 启动绑定注册热键回调
    func registerDynamicHotkey(name: String, action: @escaping () -> Void) {
        let shortcutName = KeyboardShortcuts.Name(name)
        KeyboardShortcuts.onKeyUp(for: shortcutName, action: action)
    }

    func unregisterDynamicHotkey(name: String) {
        let shortcutName = KeyboardShortcuts.Name(name)
        KeyboardShortcuts.disable(shortcutName)
    }
}
