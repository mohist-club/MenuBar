# MenuBarTranslator

一个 macOS 菜单栏工具:一个全局快捷键搞定「划词翻译」和「快速启动应用」。

<!-- TODO: 这里放一张实际截图或 GIF,发布前替换 -->

## 功能

- **划词翻译**:选中任意文字,按一下快捷键就弹出翻译结果,支持 OpenAI / DeepL / 本地 Ollama 三种翻译引擎,可以随时切换
- **没划词也能翻**:同一个快捷键,没有选中内容时会弹出一个空白输入框,直接打字或粘贴翻译,回车出结果
- **智能判断翻译方向**:自动识别原文是什么语言(覆盖 50+ 种语言),决定翻成你配置的「主语言」还是「备语言」,弹窗里也能随时手动改成其它语言
- **应用快捷启动**:给任意已安装的应用绑定一个全局快捷键,类似 Raycast 的 Quicklinks
- **窗口可拖动、可调整大小、会记住你上次的位置和尺寸**
- **支持锁定窗口**,失去焦点也不会自动关闭
- **浅色 / 深色 / 跟随系统** 三种外观,macOS 26(Tahoe)及以上系统会使用原生的 Liquid Glass 效果

## 安装

### 方式一:直接下载

去 [Releases](../../releases) 页面下载最新的 `MenuBarTranslator.zip`,解压后把 `MenuBarTranslator.app` 拖进「应用程序」文件夹。

### 方式二:Homebrew

```bash
brew install --cask <你的用户名>/tap/menubartranslator
```
<!-- TODO: 如果你后续提交到了官方 homebrew-cask 仓库,改成 `brew install --cask menubartranslator` -->

## 首次使用

1. 打开后会提示需要「辅助功能」权限(划词、全局快捷键都依赖这个),按提示去系统设置里勾选
2. 点菜单栏图标 → 设置,选一个翻译服务商并填好对应配置:
   - **OpenAI**:需要去 [platform.openai.com](https://platform.openai.com) 申请 API Key(和 ChatGPT Plus 订阅是两套完全独立的计费系统,互不相通)
   - **DeepL**:需要去 [deepl.com/pro-api](https://www.deepl.com/pro-api) 申请 API Key,免费版每月有额度
   - **Ollama**:需要自己先装好 [Ollama](https://ollama.com) 并在本地跑一个模型,完全免费、不联网、不需要 API Key
3. 在「应用快捷启动」里按需绑定几个常用应用

## 隐私说明

本应用不会收集或上传你的任何数据。但请注意:

- 使用 OpenAI 或 DeepL 时,你划词/输入的文本会**发送给你自己配置的那家服务商**做翻译,具体隐私政策以对应服务商官网为准
- 使用 Ollama 时,翻译完全在你本机进行,不会有任何网络请求发出去
- API Key 统一存储在 macOS 系统钥匙串(Keychain)里,不会以明文形式落盘或上传到任何地方

## 从源码编译

需要 macOS 13+ 和 Xcode 15+(或 Swift 5.9+ 命令行工具)。

```bash
git clone https://github.com/<你的用户名>/MenuBarTranslator.git
cd MenuBarTranslator
swift build -c release      # 编译
./build.sh                  # 打包成 .app
```

更详细的开发说明见 [CONTRIBUTING.md](CONTRIBUTING.md) 和 [DEVELOPMENT.md](DEVELOPMENT.md)。

## 技术栈

Swift + SwiftUI + AppKit,通过 Swift Package Manager 管理,没有用 Xcode 工程文件,`Package.swift` 里可以直接看到全部依赖。

## License

[MIT](LICENSE)
