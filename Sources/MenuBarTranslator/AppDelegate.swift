import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    let permissionManager = PermissionManager.shared
    let appLauncher = AppLauncher.shared
    let hotkeyManager = HotkeyManager.shared
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard InstallationManager.requireCanonicalInstallation() else {
            NSApp.terminate(nil)
            return
        }
        // 纯菜单栏应用,不需要 Dock 图标(同时也在 Info.plist 里设置 LSUIElement=YES 做双重保险)
        NSApp.setActivationPolicy(.accessory)

        KeychainHelper.migrateLegacyKeyIfNeeded()
        setupStatusItem()

        // 始终注册热键。KeyboardShortcuts 不需要在启动时弹授权；取词时会
        // 静默尝试 AX 并自动走剪贴板兜底。仅用户在设置中主动操作时才请求权限。
        hotkeyManager.registerAllHotkeys()
        appLauncher.registerAllLaunchHotkeys()
        permissionManager.checkAccessibilityPermission { _ in }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Translator")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func checkForUpdates() {
        AutoUpdater.checkForUpdates()
    }

    @objc private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = NSHostingController(rootView: SettingsView().frame(width: 560, height: 420))
        let window = NSWindow(contentViewController: controller)
        window.title = "MenuBar Translator 设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.isReleasedWhenClosed = false
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
