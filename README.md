# Poptro

一个 macOS 菜单栏工具:一个全局快捷键搞定「划词翻译」和「快速启动应用」。

<!-- TODO: 这里放一张实际截图或 GIF,发布前替换 -->

## 功能

- **划词翻译**:选中任意文字,按一下快捷键就弹出翻译结果,支持智谱 GLM / OpenAI / DeepL / Groq / Google AI / 本地 Ollama,可以随时切换
- **读取可用模型**:OpenAI、Groq、Google AI、智谱与 Ollama 均可从服务商接口读取当前账号可用模型，不依赖写死的下拉列表
- **快速切换服务**:翻译窗口左下角只列出已经配置的服务，切换后立即使用新服务重新翻译
- **键盘优先**:`Command + Return` 复制译文，`Command + Delete` 重置当前原文与译文
- **没划词也能翻**:同一个快捷键,没有选中内容时会弹出一个空白输入框,直接打字或粘贴翻译,回车出结果
- **智能判断翻译方向**:自动识别原文是什么语言(覆盖 50+ 种语言),决定翻成你配置的「主语言」还是「备语言」,弹窗里也能随时手动改成其它语言
- **应用快捷启动**:给任意已安装的应用绑定一个全局快捷键,类似 Raycast 的 Quicklinks
- **窗口可拖动、可调整大小、会记住你上次的位置和尺寸**
- **支持锁定窗口**,失去焦点也不会自动关闭
- **浅色 / 深色 / 跟随系统** 三种外观

## 安装

去 [Releases](https://github.com/mohist-club/Poptro/releases) 页面下载最新的 `Poptro.dmg`,打开后把 `Poptro.app` 拖进「应用程序」文件夹。

### ⚠️ 首次打开被系统拦截怎么办

这个项目目前是**免费开源、个人维护**,没有走 Apple 的付费开发者签名认证($99/年)。所以你**首次**双击打开时,大概率会看到类似「无法打开,因为无法验证开发者」或「已损坏,无法打开」的提示——这是正常现象,**不是文件真的损坏了**,按下面步骤操作一次就好,以后就能正常双击打开:

1. 双击打开 `Poptro.app`,会弹出提示说无法打开
2. 打开 **系统设置 → 隐私与安全性**,往下滚动,能看到一条关于 Poptro 被阻止打开的提示
3. 点 **仍要打开**,输入你的 Mac 密码确认
4. 之后正常双击图标就能打开了,不会再提示

## 首次使用

1. 打开后会提示需要「辅助功能」权限(划词、全局快捷键都依赖这个),按提示去系统设置里勾选
2. 点菜单栏图标 → 设置,选一个翻译服务商并填好对应配置:
   - **智谱 GLM（默认）**:默认使用免费的 `GLM-4-Flash-250414`，仍需申请自己的 API Key
   - **OpenAI**:需要去 [platform.openai.com](https://platform.openai.com) 申请 API Key(和 ChatGPT Plus 订阅是两套完全独立的计费系统,互不相通)
   - **DeepL**:需要去 [deepl.com/pro-api](https://www.deepl.com/pro-api) 申请 API Key,免费版每月有额度
   - **Groq**:填写 Groq API Key 后可读取账号当前支持的模型
   - **Google AI**:填写 Google AI Studio API Key 后可读取支持 `generateContent` 的 Gemini 模型
   - **Ollama**:需要自己先装好 [Ollama](https://ollama.com) 并在本地跑一个模型,完全免费、不联网、不需要 API Key
3. 在「应用快捷启动」里按需绑定几个常用应用

## 隐私说明

本应用不会收集或上传你的任何数据。但请注意:

- 使用在线服务时,你划词/输入的文本会**发送给你当前选择的服务商**做翻译,具体隐私政策以对应服务商官网为准
- 使用 Ollama 时,翻译完全在你本机进行,不会有任何网络请求发出去
- API Key 仅保存在本机，并使用与当前 Mac 绑定的 AES-GCM 密钥加密，不会以明文形式落盘或上传

## 从源码编译

需要 macOS 13+ 和 Xcode 15+(或 Swift 5.9+ 命令行工具)。

```bash
git clone https://github.com/mohist-club/Poptro.git
cd Poptro
swift build -c release      # 编译
./build.sh                  # 打包成 .app(会自动做 ad-hoc 签名)
```

更详细的开发说明见 [CONTRIBUTING.md](CONTRIBUTING.md) 和 [DEVELOPMENT.md](DEVELOPMENT.md)。

## 技术栈

Swift + SwiftUI + AppKit,通过 Swift Package Manager 管理,没有用 Xcode 工程文件,`Package.swift` 里可以直接看到全部依赖。

## License

[MIT](LICENSE)
