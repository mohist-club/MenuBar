import AppKit
import Foundation

final class AppLauncher: ObservableObject {
    static let shared = AppLauncher()

    @Published var bindings: [LaunchBinding]

    private let filename = "launch_bindings.json"

    private init() {
        self.bindings = LocalStore.load([LaunchBinding].self, filename: "launch_bindings.json", default: [])
    }

    // MARK: - 枚举已安装应用

    /// 扫描 /Applications、/System/Applications、~/Applications,返回 (名称, 路径) 列表,按名称排序
    func scanInstalledApplications() -> [(name: String, path: String)] {
        let fm = FileManager.default
        var results: [(String, String)] = []

        let searchDirs = [
            "/Applications",
            "/System/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        ]

        for dir in searchDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let fullPath = (dir as NSString).appendingPathComponent(item)
                let name = (item as NSString).deletingPathExtension
                results.append((name, fullPath))
            }
        }

        return results.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    func icon(forAppPath path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    // MARK: - 绑定管理

    func addBinding(appName: String, appBundlePath: String) {
        let binding = LaunchBinding(appName: appName, appBundlePath: appBundlePath)
        bindings.append(binding)
        persist()
        registerHotkey(for: binding)
    }

    func removeBinding(_ binding: LaunchBinding) {
        HotkeyManager.shared.unregisterDynamicHotkey(name: binding.hotkeyName)
        bindings.removeAll { $0.id == binding.id }
        persist()
    }

    func setEnabled(_ enabled: Bool, for binding: LaunchBinding) {
        guard let index = bindings.firstIndex(where: { $0.id == binding.id }) else { return }
        bindings[index].isEnabled = enabled
        if enabled {
            registerHotkey(for: bindings[index])
        } else {
            HotkeyManager.shared.unregisterDynamicHotkey(name: binding.hotkeyName)
        }
        persist()
    }

    private func persist() {
        LocalStore.save(bindings, filename: filename)
    }

    // MARK: - 热键注册与触发

    func registerAllLaunchHotkeys() {
        for binding in bindings {
            if binding.isEnabled { registerHotkey(for: binding) }
        }
    }

    private func registerHotkey(for binding: LaunchBinding) {
        HotkeyManager.shared.registerDynamicHotkey(name: binding.hotkeyName) { [weak self] in
            self?.launch(binding)
        }
    }

    private func launch(_ binding: LaunchBinding) {
        let url = URL(fileURLWithPath: binding.appBundlePath)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                print("启动应用失败: \(error)")
            }
        }
    }
}
