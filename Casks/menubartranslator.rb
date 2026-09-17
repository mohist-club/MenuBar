cask "menubartranslator" do
  # TODO: 每次发新版本后更新这三行:
  #   1. version 改成新版本号
  #   2. url 改成对应 tag 的 Release 里 MenuBarTranslator.zip 的下载链接
  #   3. sha256 用 `shasum -a 256 MenuBarTranslator.zip` 算出来的值替换,
  #      不知道校验值就先写 :no_check(不建议长期这样,失去了完整性校验的意义)
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/<你的GitHub用户名>/MenuBarTranslator/releases/download/v#{version}/MenuBarTranslator.zip"
  name "MenuBarTranslator"
  desc "划词翻译 + 全局快捷键启动应用的菜单栏工具"
  homepage "https://github.com/<你的GitHub用户名>/MenuBarTranslator"

  depends_on macos: ">= :ventura"

  app "MenuBarTranslator.app"

  zap trash: [
    "~/Library/Application Support/MenuBarTranslator",
    "~/Library/Preferences/com.menubartranslator.app.plist"
  ]
end
