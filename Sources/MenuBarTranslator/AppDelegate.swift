import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    let permissionManager = PermissionManager.shared
    let appLauncher = AppLauncher.shared
    let hotkeyManager = HotkeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纯菜单栏应用,不需要 Dock 图标(同时也在 Info.plist 里设置 LSUIElement=YES 做双重保险)
        NSApp.setActivationPolicy(.accessory)

        KeychainHelper.migrateLegacyKeyIfNeeded()
        setupStatusItem()

        // 启动时检查辅助功能权限,未授权则引导用户开启
        permissionManager.ensureAccessibilityPermission { granted in
            if granted {
                self.hotkeyManager.registerAllHotkeys()
                self.appLauncher.registerAllLaunchHotkeys()
            }
        }
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

    // 用系统原生的 Settings 场景机制(App.swift 里声明的 `Settings { SettingsView() }`)来开窗口,
    // 而不是自己再手搓一个 NSWindow——之前手动建窗口和 SwiftUI 的 Settings scene 各管一份,
    // 两边打架导致关掉窗口后又莫名重新弹出来。用系统这套只有一个入口,不会再冲突。
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
