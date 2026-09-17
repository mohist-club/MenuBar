# Poptro

类 Raycast 的快捷键启动应用 + 类 Bob 的划词翻译(OpenAI 驱动),菜单栏常驻。

## 重要说明

项目已在 macOS 真机完成编译、安装与基础功能验证。涉及 Accessibility API 的划词能力
仍可能因目标应用的控件实现不同而存在兼容差异。

## 环境要求

- macOS 13 (Ventura) 及以上
- Xcode 15+ 或 Swift 5.9+ 命令行工具

## 编译运行

```bash
cd Poptro
swift build            # 调试模式,直接跑
swift run               # 编译并运行(会在菜单栏出现图标)
```

打包成正式 .app(推荐,LSUIElement 等 Info.plist 配置只有在 .app bundle 里才生效):

```bash
./build.sh
codesign --force --deep --sign - Poptro.app   # 本地自签
open Poptro.app
```

## 首次运行

1. 启动后会弹出"需要辅助功能权限"提示,点击"前往系统设置",
   在 `系统设置 -> 隐私与安全性 -> 辅助功能` 里勾选本应用。
2. 点击菜单栏图标 -> 设置,在“翻译设置”里填写 API Key；密钥仅在本机加密保存。
3. 在"应用快捷启动"里添加要绑定的应用并录制快捷键。
4. 划词后按默认快捷键 `Option + D`(可在设置里改)触发翻译弹窗。

## 项目结构

```
Sources/Poptro/
├── App.swift                      SwiftUI App 入口
├── AppDelegate.swift              状态栏图标、菜单、启动流程
├── Models/Models.swift            数据模型 + 本地 JSON 持久化
├── Services/
│   ├── PermissionManager.swift    辅助功能权限检测与引导
│   ├── HotkeyManager.swift        全局热键注册(基于 KeyboardShortcuts 库)
│   ├── AppLauncher.swift          扫描已安装 App + 快捷启动绑定管理
│   ├── TextCaptureService.swift   划词捕获(AX API 优先,Cmd+C 模拟兜底)
│   ├── TranslationService.swift   OpenAI 流式翻译请求(SSE)
│   └── TranslationFlowCoordinator.swift  取词->翻译->展示 的流程编排
├── UI/
│   ├── FloatingPanel.swift        悬浮翻译结果窗口(NSPanel + 毛玻璃)
│   └── SettingsView.swift         设置界面(通用/快捷启动/翻译/关于)
└── Utils/KeychainHelper.swift     API Key 安全存储
```

## 已知需要你在真机上验证/可能要改的点

1. **Accessibility 取选中文字**:很多非原生控件(部分 Electron App、浏览器插件场景)
   `kAXSelectedTextAttribute` 取不到,代码里已做 Cmd+C 模拟兜底,但具体延时(当前 120ms)
   可能需要根据实测调整,太短会取到旧剪贴板内容。
2. **KeyboardShortcuts 库版本**:Package.swift 里锁定 `from: "2.2.0"`,建议编译前检查
   GitHub 上的最新版本号,API 基本稳定但个别方法签名可能随版本变化。
3. **签名与分发**:本地自签名(`codesign --sign -`)可以正常调试,但每次重新编译
   签名会变化,系统可能要求重新授权辅助功能权限。正式分发需要 Apple Developer ID
   签名 + 公证(notarization),否则用户首次打开会被 Gatekeeper 拦截,且无法稳定
   保持辅助功能权限。
4. **App Sandbox**:本应用不能开启 App Sandbox(会阻断 AX API 和模拟按键能力),
   因此**不适合上架 Mac App Store**,只能走公证后直接分发(和 Raycast、Bob 一样的模式)。
5. **多屏幕/边界情况**:悬浮窗定位目前简单地贴在鼠标下方,靠近屏幕边缘时可能超出可视区域,
   建议加一层屏幕边界检测做位置修正。
6. **流式 SSE 解析**:`TranslationService.swift` 里手写了简易的按行解析,如果 OpenAI
   返回的分包正好把一行 JSON 切断,当前逻辑靠 buffer 累积处理,但建议编译后用长文本
   实测一下稳定性。
