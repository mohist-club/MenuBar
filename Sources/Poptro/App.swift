import SwiftUI

@main
struct PoptroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 主窗口就是设置窗口,平时不显示,通过状态栏菜单唤出
        Settings {
            SettingsView()
                .frame(width: 560, height: 420)
        }
    }
}
