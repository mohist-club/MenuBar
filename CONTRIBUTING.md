# 参与贡献

欢迎提交 Issue 和 Pull Request!提交前看一眼下面这几条,能让协作更顺畅。

## 开发环境

- macOS 13 及以上,Xcode 15+ 或 Swift 5.9+ 命令行工具
- 用 Xcode 打开项目根目录(File → Open… 选中含 `Package.swift` 的文件夹),或直接 `swift build` / `swift run`

## 提交 Issue

- **Bug 反馈**:请说明复现步骤、macOS 版本、用的是 OpenAI 还是 DeepL(如果和翻译相关)
- **功能建议**:说清楚具体用途和期望的交互方式,方便讨论

## 提交 Pull Request

1. Fork 本仓库,从 `main` 切一个新分支
2. 改动尽量聚焦单一主题,不要一个 PR 塞好几个不相关的改动
3. 涉及 UI 改动的话,截图或录屏贴在 PR 描述里
4. 确保 `swift build` 能正常编译通过,有对应测试的话跑一下 `swift test`
5. Commit message 用简短的祈使句描述改了什么(比如 "Add Ollama provider support" 而不是 "fix stuff")

## 代码风格

- 缩进用 4 个空格
- 公开的类型/方法尽量加文档注释说明用途,尤其是有"为什么这么做"背景的地方(比如绕开某个系统限制的 workaround),写清楚原因比写清楚做法更重要
- 新增的翻译服务商、语言,尽量遵循现有的 `TranslationProvider` / `SupportedLanguage` 这套可扩展的枚举 + 目录模式,不要为单个服务商特殊硬编码分支逻辑

## 有疑问?

直接开一个 Issue 讨论,或者在已有的相关 Issue/PR 下面留言。
