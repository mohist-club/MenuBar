import Sparkle

/// Sparkle 自动更新的封装。使用前你需要自己做三件事(我这边生成不了):
/// 1. 运行 Sparkle 自带的 generate_keys 工具生成一对 EdDSA 密钥
///    (装 Sparkle 后在 .build 或 SPM checkout 里能找到,或者去 Sparkle 仓库的 bin/ 目录下载)
/// 2. 把公钥填进 Resources/Info.plist 的 SUPublicEDKey 字段(现在是占位符)
/// 3. 每次发新版本时,生成一份 appcast.xml(列出各版本下载链接和用私钥签好的签名),
///    传到你 GitHub Pages 或仓库里能公开访问到的地方,同时把 Info.plist 里的
///    SUFeedURL 改成指向这份 appcast.xml 的地址
enum AutoUpdater {
    static let shared = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    /// 手动触发"检查更新",挂到菜单栏的"检查更新…"菜单项上
    static func checkForUpdates() {
        shared.checkForUpdates(nil)
    }
}
