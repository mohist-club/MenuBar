import AppKit

/// Checks GitHub Releases and opens the matching DMG download. In-place
/// replacement remains intentionally manual until Developer ID notarization.
enum AutoUpdater {
    private static let releasesURL = URL(string: "https://api.github.com/repos/mohist-club/Poptro/releases/latest")!

    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]
    }

    static func checkForUpdates() {
        var request = URLRequest(url: releasesURL)
        request.setValue("Poptro", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard let data, let release = try? JSONDecoder().decode(Release.self, from: data) else {
                    showError(error?.localizedDescription ?? "无法读取 GitHub Release 信息")
                    return
                }
                present(release)
            }
        }.resume()
    }

    private static func present(_ release: Release) {
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let alert = NSAlert()
        if latest.compare(current, options: .numeric) == .orderedDescending {
            alert.messageText = "发现新版本 \(release.tag_name)"
            alert.informativeText = "当前版本：\(current)\n下载后打开 DMG，将 App 拖到“应用程序”完成替换。"
            alert.addButton(withTitle: "下载 DMG")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn {
                let dmg = release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }?.browser_download_url ?? release.html_url
                NSWorkspace.shared.open(dmg)
            }
        } else {
            alert.messageText = "已是最新版本"
            alert.informativeText = "当前版本：\(current)"
            alert.runModal()
        }
    }

    private static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = message
        alert.runModal()
    }
}
