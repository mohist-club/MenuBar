cask "poptro" do
  # 注意:这个 Cask 文件目前只是模板,还不能直接 `brew tap` 使用——
  # Homebrew 的 tap 简写(`brew tap <用户名>/<名字>`)要求 tap 仓库名字必须是
  # `homebrew-<名字>` 这种格式,而这个仓库叫 Poptro,不符合命名规则。
  # 要真正支持 `brew install --cask` 有两个办法:
  #   1. 提交到官方 homebrew-cask 仓库(有审核流程,用户体验最好)
  #   2. 额外建一个专门叫 homebrew-tap 的仓库,把这个文件放进去
  # 在那之前,用户直接从下面这行 url 对应的地址下载安装就行,或者手动执行:
  #   brew install --cask ./Casks/poptro.rb
  #
  # TODO: 每次发新版本后更新这三行:
  #   1. version 改成新版本号
  #   2. url 改成对应 tag 的 Release 里 Poptro.zip 的下载链接
  #   3. sha256 用 `shasum -a 256 Poptro.zip` 算出来的值替换,
  #      不知道校验值就先写 :no_check(不建议长期这样,失去了完整性校验的意义)
  version "1.2.1"
  sha256 :no_check

  url "https://github.com/mohist-club/Poptro/releases/download/v#{version}/Poptro.zip"
  name "Poptro"
  desc "划词翻译 + 全局快捷键启动应用的菜单栏工具"
  homepage "https://github.com/mohist-club/Poptro"

  depends_on macos: ">= :ventura"

  app "Poptro.app"

  zap trash: [
    "~/Library/Application Support/Poptro",
    "~/Library/Application Support/MenuBarTranslator",
    "~/Library/Preferences/com.menubartranslator.app.plist"
  ]
end
