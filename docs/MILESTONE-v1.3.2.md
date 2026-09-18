# Poptro v1.3.2 里程碑总结

> 状态：已发布  
> 发布日期：2026-09-18  
> 基准提交：`bfd93bb`  
> Release：<https://github.com/mohist-club/Poptro/releases/tag/v1.3.2>

## 1. 里程碑定位

v1.3.2 是 Poptro 从“功能原型”进入“可以日常使用和持续迭代”的阶段性版本。
本阶段没有继续堆叠大量新功能，而是完成以下闭环：

1. 用一个常驻、轻量的 macOS 菜单栏应用替代常用的快捷启动和划词翻译流程。
2. 让全局快捷键、辅助功能权限、划词读取和翻译弹窗形成稳定链路。
3. 支持多家在线翻译服务和本地模型，并只展示用户已配置的服务。
4. 把个人配置限制在本机，避免把 API Key、个人快捷键或应用路径提交到仓库。
5. 建立 GitHub CI、Release、DMG/ZIP 安装包和应用内版本检测流程。
6. 将设置页和翻译窗口收敛为原生 macOS 视觉，并兼容浅色、深色和玻璃材质。

## 2. 已交付能力

### 2.1 常驻与快捷键

- 菜单栏常驻，不显示 Dock 图标。
- 内置且不可删除的“划词翻译”快捷键，默认 `Command + G`，允许修改或停用。
- 支持为任意已安装应用添加独立全局快捷键。
- 应用选择使用系统应用选择界面，不要求用户手写 `.app` 路径。
- 快捷键监听与设置窗口解耦，触发翻译不会打开整个设置界面。

### 2.2 划词与手动翻译

- 优先通过 Accessibility API 读取焦点控件的选中文字。
- AX 读取失败时，模拟 `Command + C` 兜底，并完整恢复原剪贴板。
- 没有读到选中文字时打开手动输入模式，而不是直接失败退出。
- 自动识别源语言，并按主语言 / 备用语言决定目标语言。
- 支持手动切换语种、互换原文与译文、朗读、复制。
- `Command + Return` 复制译文，`Command + Delete` 重置内容。
- 使用请求 ID 隔离并发翻译，已取消或已过期的流式结果不会回写新窗口。

### 2.3 翻译服务

- 智谱 GLM
- OpenAI
- DeepL
- Groq
- Google AI（Gemini）
- Ollama 本地模型

服务页支持保存配置、读取服务商可用模型、设置唯一默认服务、连接测速与状态展示。
翻译窗口左下角只列出实际配置成功的服务，切换后会立即使用新服务重新翻译。

### 2.4 原生界面

- 设置页采用原生左右栏结构。
- 翻译窗口采用可拖动、可缩放的双栏原文 / 译文布局。
- 支持浅色、深色和跟随系统。
- macOS 26 及以上使用系统 Liquid Glass 能力；旧系统使用 `NSVisualEffectView` 回退。
- 玻璃透明度可配置；阅读区域保持中性底层，避免桌面颜色干扰正文。
- 正文统一为 16pt 原生字体和紧凑行距。
- 左右文本区强制使用 overlay 滚动条，避免系统“始终显示滚动条”造成宽白轨道。

### 2.5 本地数据与隐私

- 普通配置存放在 `~/Library/Application Support/Poptro/`。
- 从旧的 `MenuBarTranslator` 目录无损迁移配置。
- API Key 只在用户点击保存时写入本机，使用 AES-GCM 加密后存储。
- 加密密钥从当前 Mac 的硬件标识派生，配置文件中不会出现可读明文 Key。
- 在线翻译文本只发送给当前选择的服务商；Ollama 路径可完全留在本机。

### 2.6 安装和更新

- 应用要求从固定路径 `/Applications/Poptro.app` 运行，以稳定 macOS TCC 权限身份。
- GitHub Release 同时生成 DMG 和 ZIP。
- DMG 内提供指向 `/Applications` 的拖拽安装入口。
- 应用内通过 GitHub Releases API 比较版本号并打开对应 DMG。
- 当前默认发布为 ad-hoc 签名；Developer ID 签名和公证流程已预留为手动工作流。

## 3. 验收结果

- 本地 Debug / Release 编译通过。
- 23 项自动测试通过。
- GitHub Actions CI 通过。
- GitHub Release 构建和资产上传通过。
- `codesign --verify --deep --strict` 通过。
- v1.3.2 DMG 和 ZIP 可直接从 GitHub Release 下载。
- 项目中未提交个人 API Key、Lark 等个人应用绑定或用户本机绝对路径。

## 4. 当前边界

- ad-hoc 签名不是 Apple Developer ID，首次安装仍可能被 Gatekeeper 拦截。
- 未公证版本更新仍采用“下载 DMG 后手动覆盖”，不做静默原地替换。
- 部分 Electron、网页画布或自绘控件不提供 `kAXSelectedTextAttribute`，只能依赖模拟复制兜底。
- API Key 的本地加密用于避免明文落盘，不等同于 Secure Enclave 或稳定 Developer ID 下的 Keychain 访问控制。
- 翻译质量、可用模型和免费额度由各服务商决定，可能随时间变化。

## 5. 下一阶段建议

1. 申请 Apple Developer Program，完成 Developer ID 签名、公证和稳定更新链路。
2. 增加真实应用兼容矩阵：Safari、Chrome、Lark、微信、Office、Electron 编辑器等。
3. 为翻译流、剪贴板恢复、窗口生命周期和设置迁移增加更多自动测试。
4. 将中文 / 英文字符串迁移到标准本地化资源。
5. 增加可选的诊断日志导出，默认不记录原文、译文和 API Key。
6. 补充真实产品截图和演示 GIF。

