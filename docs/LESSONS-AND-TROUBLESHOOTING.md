# Poptro 踩坑与故障排查

本文记录 v1.3.2 之前反复出现、成本较高的问题。格式统一为“现象 → 根因 → 标准解法 → 禁止做法”。

## 1. 已授权却一直提示未授权

**现象**

- 系统设置里已经勾选 Poptro，但应用仍显示未授权。
- 隐私列表里出现多个相同名称的 Poptro / MenuBarTranslator。
- 每次覆盖安装或重新构建后都要再授权。

**根因**

TCC 识别的不只是展示名称。项目目录、Downloads、DMG 挂载卷和 `/Applications` 下的 App
可能被视为不同对象；ad-hoc 重新签名还会让身份稳定性更差。

**标准解法**

1. 正式版本只保留 `/Applications/Poptro.app`。
2. 完全退出所有旧实例。
3. 从 DMG 拖入“应用程序”，再从 `/Applications` 启动。
4. 系统设置里删除旧条目后，重新添加该固定路径的 App。
5. 应用启动时校验运行路径，错误副本直接提示并退出。

**禁止做法**

- 从构建目录反复运行不同签名的 `.app`。
- 在启动和每次翻译时调用带 prompt 的权限 API。
- 通过连续弹授权窗口掩盖身份不一致。

## 2. 授权弹窗反复出现或应用闪退

**根因**

- 权限检查、热键和翻译流程耦合。
- 在系统弹窗或设置跳转期间重复创建窗口和请求授权。
- Keychain 项目的签名访问身份随 ad-hoc 构建变化。

**标准解法**

- 启动只做 `AXIsProcessTrusted()` 静默检查。
- 显式按钮才调用带 prompt 的权限请求。
- 热键始终注册；取词失败时进入手动输入。
- 个人 API Key 只在用户点击保存时写入本机 AES-GCM 密文，避免每次读取触发登录钥匙串询问。

## 3. 划词后读不到文本

**根因**

- 很多 Electron、浏览器或自绘控件不实现 `kAXSelectedTextAttribute`。
- 模拟复制读取太快，得到旧剪贴板。
- 没有检查剪贴板 `changeCount`。
- Poptro 抢到焦点后才开始读取，原应用的选区已经丢失。

**标准解法**

- 热键触发后先保持原应用状态并立即尝试 AX。
- AX 失败时模拟 `Command + C`，当前等待 120ms。
- 只有剪贴板确实变化才读取文本。
- 读取后恢复全部剪贴板类型。
- 最终失败时打开手动输入，而不是提示死路错误。

## 4. 翻译快捷键触发了设置窗口或所有快捷键失效

**根因**

- 菜单命令、设置窗口和全局热键复用了错误的 action。
- 录制快捷键时全局监听仍在响应。
- 动态快捷键名称不稳定或重复注册。
- 某次翻译结束时错误地注销了所有监听。

**标准解法**

- `HotkeyManager` 只负责监听，业务统一进入 `TranslationFlowCoordinator`。
- 设置窗口使用独立 action。
- 翻译快捷键使用固定名称，应用快捷键使用持久化 UUID 名称。
- 启用 / 停用只影响目标快捷键，不重置整个快捷键系统。

## 5. 第一次翻译后按钮或快捷键不再工作

**根因**

- 面板关闭、重建和异步流回调之间发生生命周期竞争。
- 旧请求在新面板创建后继续回写状态。
- 把“结束当前翻译”误实现为“注销快捷键”。

**标准解法**

- 每次翻译使用独立 `activeTranslationID`。
- 新请求、重置和关闭必须让旧请求失效。
- 快捷键生命周期与单次翻译生命周期完全分离。
- 面板回调使用弱引用，并在主线程更新状态。

## 6. 点击设置第二次闪退或无法打开

**根因**

- 每次点击都创建新窗口，旧窗口状态和观察者没有正确释放。
- 窗口关闭后仍保留悬空引用，或被自动释放后继续访问。

**标准解法**

- `AppDelegate` 持有并复用唯一设置窗口。
- 设置 `isReleasedWhenClosed = false`。
- 再次点击只调用 `makeKeyAndOrderFront` 并激活 App。

## 7. API Key 每次都要求钥匙串密码

**根因**

ad-hoc 签名没有稳定的 Keychain 访问身份，更新后的构建可能被视为另一个客户端。

**当前解法**

- API Key 使用 AES-GCM 加密后保存到当前用户的 UserDefaults。
- 加密材料绑定当前 Mac 硬件 UUID。
- 只在用户点击“保存”时写入。

**安全边界**

这能避免明文落盘和跨机器直接读取，但同一用户、同一机器上的高权限攻击者仍可能推导密钥。
取得稳定 Developer ID 后，可以重新评估带明确 access control 的 Keychain 方案。

## 8. 覆盖安装后出现多个应用副本或备份目录

**根因**

手工把旧版本改名为 `Poptro.app.pre-vXXX` 并留在 `/Applications`，Spotlight、LaunchServices
和 TCC 都可能继续识别这些 bundle。

**标准解法**

- `/Applications` 只保留一个正式 `Poptro.app`。
- 需要备份时，把旧包移到普通归档目录或压缩文件，不要让它继续作为 `.app` bundle 被系统扫描。
- DMG 安装采用拖拽覆盖，不在 Applications 里制造永久备份目录。

## 9. 玻璃窗口四角、底色和文本看起来不一致

**根因**

- SwiftUI 背景、HostingView layer 和窗口本身使用不同圆角或不同裁切。
- 直接让桌面颜色穿透正文区域，导致浅色模式偏蓝。
- 使用纯黑 / 纯白文本和高对比按钮破坏系统材质层级。

**标准解法**

- 外层背景、裁切、描边和 HostingView 统一 continuous radius。
- 玻璃作为窗口材质；正文区叠加适度中性 `textBackgroundColor`。
- 使用语义色和低对比 control background。
- 同时检查浅色、深色、降低透明度和不同壁纸。

## 10. 系统设置为“始终显示滚动条”后出现白色宽轨

**根因**

普通 `NSScrollView` 会在挂载窗口后重新读取系统偏好。只在初始化时写
`scrollerStyle = .overlay`，之后仍可能被系统改回 legacy 样式。

**标准解法**

- 使用专用 `OverlayTextScrollView`，在属性入口和 `viewDidMoveToWindow` 阶段固定 overlay。
- 原文和译文都使用相同的 AppKit 文本滚动容器。
- 自动测试在面板实际渲染后检查 `scrollerStyle`、自动隐藏和正文点数。

## 11. 新版本增加字段后用户配置全部恢复默认

**根因**

依赖编译器合成的 `Codable` 解码时，旧 JSON 缺少新字段会导致整个对象解码失败。

**标准解法**

- 为长期持久化模型手写 `init(from:)`。
- 每个字段使用 `decodeIfPresent` 并提供默认值。
- 增加“缺字段”和“未知额外字段”的回归测试。

## 12. 翻译测速偶发 `The network connection was lost`

**根因**

短时网络波动、DNS、连接复用或服务端主动断开不代表配置永久失效。

**标准解法**

- 只对明确的瞬时网络错误自动重试一次。
- 使用短测试文本，限制额度消耗。
- UI 只保留一处清楚的错误信息，避免卡片和底栏重复提示。
- 认证失败、配额不足和模型不存在不能按网络错误重试。

## 13. GitHub 已推送代码但 Releases 没有安装包

**根因**

Release workflow 由 `v*` 标签触发；只推送 `main` 不会创建 Release。

**标准解法**

1. 更新 `CFBundleShortVersionString`、`CFBundleVersion` 和 Cask 版本。
2. 提交并推送 `main`。
3. 创建并推送同版本标签，如 `v1.3.2`。
4. 等待 Release workflow 完成。
5. 确认 Release 同时包含 `Poptro.dmg` 和 `Poptro.zip`。

## 14. 暗黑模式下正文仍然是黑色

**根因**

`NSTextView` 把写入 `textStorage` 的颜色按当时外观解析成静态值。面板在创建后再切换为
深色外观时，SwiftUI 的语义色会更新，但 AppKit 文本存储里原先的黑色不会自动重算。

**标准解法**

- 文本视图监听 `viewDidChangeEffectiveAppearance()`。
- 在该回调内按 `effectiveAppearance` 重新解析 `NSColor.labelColor`。
- 同步更新正文属性、输入属性和插入光标颜色。
- 自动测试先切深色再切浅色，分别验证正文亮度，而不是只检查颜色对象名称。
