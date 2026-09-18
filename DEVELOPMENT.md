# Poptro 开发指南

本文只保留开发者快速入口，避免与详细工程文档重复并逐渐失真。

## 环境要求

- macOS 13（Ventura）及以上
- Xcode 15+ 或 Swift 5.9+
- Swift Package Manager

## 本地编译

```bash
swift build
swift test
swift build -c release
```

生成完整 App、DMG 和 ZIP：

```bash
./build.sh
```

`swift run` 适合检查纯代码流程，但辅助功能权限与正式安装路径强相关。
需要验证划词、全局快捷键和权限时，应构建固定的 `.app`，并从
`/Applications/Poptro.app` 运行，不能长期使用项目目录中的临时副本。

## 开发入口

- [架构说明](docs/ARCHITECTURE.md)
- [工程与 UI 标准](docs/ENGINEERING-STANDARDS.md)
- [踩坑与故障排查](docs/LESSONS-AND-TROUBLESHOOTING.md)
- [发布检查清单](docs/RELEASE-CHECKLIST.md)
- [v1.3.2 里程碑总结](docs/MILESTONE-v1.3.2.md)
- [贡献指南](CONTRIBUTING.md)

## 当前关键约束

1. 正式运行路径固定为 `/Applications/Poptro.app`。
2. 启动、热键和翻译流程不得反复触发系统授权弹窗。
3. 取词使用 AX 优先、模拟复制兜底，并恢复用户剪贴板。
4. 内置翻译快捷键默认 `Command + G`。
5. API Key 只保存在本机，不得写入源码、日志或公开配置。
6. 长期持久化模型必须兼容旧 JSON 缺失字段。
7. 每次发布必须同时验证 CI、DMG、ZIP、签名结构和 GitHub Release 资产。

## 运行测试

```bash
swift test
```

当前测试覆盖配置兼容、语言识别、服务模型路由、测速错误分类、面板渲染和
overlay 滚动条等行为。Accessibility、TCC、全局快捷键、DMG 安装和多屏幕仍需要真机测试。
