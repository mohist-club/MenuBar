# Poptro 发布检查清单

> 适用于 GitHub ad-hoc 签名发布。Developer ID 公证发布需额外执行
> `.github/workflows/release-notarized.yml` 中的证书、公证和 stapling 流程。

## 1. 发布前范围确认

- [ ] 本次版本号和发布目标明确。
- [ ] 没有未确认的崩溃、权限循环弹窗或快捷键失效问题。
- [ ] 没有真实 API Key、个人应用绑定、本机用户名路径或剪贴板内容进入 diff。
- [ ] README、里程碑、架构、工程标准和排障文档已按需更新。
- [ ] Release notes 只描述本版本实际包含的变化。

建议检查：

```bash
git status --short
git diff --check
git diff --cached --check
rg -n "sk-[A-Za-z0-9]|api[_-]?key|/Users/" \
  Sources Tests Resources README.md docs .github Casks
```

命中不一定都是泄露，但必须逐项人工确认。

## 2. 版本号

- [ ] `Resources/Info.plist` 的 `CFBundleShortVersionString` 已更新。
- [ ] `Resources/Info.plist` 的 `CFBundleVersion` 已递增。
- [ ] `Casks/poptro.rb` 的版本与 App 一致。
- [ ] 准备推送的标签为 `v<CFBundleShortVersionString>`。

检查：

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist
```

## 3. 自动测试与构建

- [ ] `swift test` 全部通过。
- [ ] `swift build -c release` 通过。
- [ ] 关键 UI 行为测试通过，特别是面板渲染和 overlay 滚动条。
- [ ] `./build.sh` 成功生成 App、DMG、ZIP。

```bash
swift test
swift build -c release
./build.sh
```

## 4. 产物验证

- [ ] App 内版本号正确。
- [ ] 深层签名验证通过。
- [ ] DMG 和 ZIP 都存在且尺寸合理。
- [ ] 记录 SHA-256，便于核对上传资产。

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  Poptro.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
  Poptro.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 Poptro.app
shasum -a 256 dist/Poptro.dmg dist/Poptro.zip
```

ad-hoc 版本中 `TeamIdentifier=not set` 是预期结果；它不等于 Developer ID 公证通过。

## 5. 真机安装验证

- [ ] 完全退出旧版 Poptro。
- [ ] 打开 DMG，将 App 拖到 `/Applications` 并覆盖旧版。
- [ ] 只从 `/Applications/Poptro.app` 启动。
- [ ] 首次 Gatekeeper 提示流程与 README 一致。
- [ ] 辅助功能列表中授权的是 `/Applications` 下的正式副本。
- [ ] 设置窗口可重复打开、关闭，不闪退。
- [ ] 开机启动切换后仍能继续编辑其他设置。

## 6. 功能冒烟测试

### 快捷键

- [ ] 默认或自定义翻译快捷键可触发。
- [ ] 录制快捷键时不会触发旧业务动作。
- [ ] 新增 Safari 等应用快捷键后可立即启动。
- [ ] 添加或删除一个应用快捷键不会导致其他快捷键全部失效。

### 划词翻译

- [ ] Safari / 系统原生文本控件可以获取选中文字。
- [ ] 至少一个 Electron 应用验证 AX 失败时的复制兜底。
- [ ] 未选中文字时进入手动输入模式。
- [ ] 翻译、重置、复制、朗读、交换语言都可用。
- [ ] `Command + Return` 和 `Command + Delete` 生效。
- [ ] 首次翻译后全局快捷键仍继续生效。

### 服务

- [ ] 只显示已配置服务。
- [ ] 唯一默认服务正确。
- [ ] 切换服务会重新翻译当前文本。
- [ ] 模型列表刷新、连接测试和测速按预期工作。
- [ ] 瞬时断网提示不重复，恢复网络后可再次测试。

### UI

- [ ] 浅色、深色、跟随系统均检查。
- [ ] 玻璃开启、关闭和透明度边界均检查。
- [ ] 系统滚动条设为“始终显示”时仍只出现 overlay 滚动条。
- [ ] 窗口四角、描边、正文底色、按钮和文字层级符合设计稿。
- [ ] 最小 / 最大尺寸和多屏幕位置恢复正常。
- [ ] 中文和英文界面无溢出。

## 7. Git 和 GitHub 发布

- [ ] 只暂存本版本相关文件。
- [ ] 提交已推送到 `main`。
- [ ] 标签已创建并推送。
- [ ] CI workflow 成功。
- [ ] Release workflow 成功。
- [ ] Release 不是 Draft / Prerelease（除非本次明确如此）。
- [ ] Release 页面包含 DMG 和 ZIP。
- [ ] 下载链接实际可访问。

```bash
git push origin main
git tag -a vX.Y.Z -m "Poptro X.Y.Z"
git push origin vX.Y.Z
gh run list --limit 6
gh release view vX.Y.Z --json url,isDraft,isPrerelease,assets
```

## 8. 发布后

- [ ] 从 GitHub 下载一次公开 DMG，而不是只验证本地产物。
- [ ] 安装公开 DMG 并复测版本号、快捷键、权限和翻译。
- [ ] 应用内“检查更新”能识别当前版本为最新。
- [ ] Release 页面和 README 的下载入口正确。
- [ ] 本地正式源码目录快进同步到发布提交。
- [ ] 若出现高成本问题，将根因和标准解法补充到排障文档。

