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

        setupStatusItem()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesChanged),
            name: .poptroPreferencesDidChange,
            object: nil
        )

        // 始终注册热键。KeyboardShortcuts 不需要在启动时弹授权；取词时会
        // 静默尝试 AX 并自动走剪贴板兜底。仅用户在设置中主动操作时才请求权限。
        hotkeyManager.registerAllHotkeys()
        appLauncher.registerAllLaunchHotkeys()
        permissionManager.checkAccessibilityPermission { _ in }

        if AppPreferencesStore.shared.values.automaticUpdateChecks {
            AutoUpdater.checkForUpdates(silentWhenCurrent: true)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = makeStatusBarIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
        }

        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let language = AppPreferencesStore.shared.values.interfaceLanguage
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: PoptroText.value("设置…", "Settings…", language: language),
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem(
            title: PoptroText.value("检查更新…", "Check for Updates…", language: language),
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: PoptroText.value("退出 Poptro", "Quit Poptro", language: language),
            action: #selector(quit),
            keyEquivalent: "q"
        ))
        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func handlePreferencesChanged() {
        rebuildStatusMenu()
        updateSettingsWindowAppearance()
    }

    private func updateSettingsWindowAppearance() {
        guard let settingsWindow else { return }
        let preferences = AppPreferencesStore.shared.values
        settingsWindow.appearance = preferences.appearanceMode.nsAppearance
        settingsWindow.title = PoptroText.value(
            "Poptro 设置",
            "Poptro Settings",
            language: preferences.interfaceLanguage
        )
    }

    /// Monochrome companion to the app icon: a Command mark whose lower-right
    /// loop becomes a speech-bubble tail. Template rendering lets macOS choose
    /// the correct foreground color for light, dark and tinted menu bars.
    private func makeStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let command = NSImage(systemSymbolName: "command", accessibilityDescription: "Poptro")?
                .withSymbolConfiguration(configuration)
            command?.draw(in: NSRect(x: 2, y: 2, width: 14, height: 14))

            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: 11.8, y: 4.1))
            tail.line(to: NSPoint(x: 16.2, y: 1.2))
            tail.line(to: NSPoint(x: 14.6, y: 6.2))
            tail.close()
            NSColor.black.setFill()
            tail.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Poptro"
        return image
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
        let controller = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1040, height: 680))
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        window.isReleasedWhenClosed = false
        self.settingsWindow = window
        updateSettingsWindowAppearance()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
