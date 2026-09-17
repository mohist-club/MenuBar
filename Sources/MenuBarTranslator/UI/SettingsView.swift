import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }

            AppLaunchSettingsView()
                .tabItem { Label("应用快捷启动", systemImage: "bolt") }

            TranslationSettingsView()
                .tabItem { Label("翻译设置", systemImage: "character.bubble") }

            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .padding(20)
    }
}

// MARK: - 通用

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Toggle("开机自动启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                }
            Text("辅助功能权限状态: \(PermissionManager.shared.isAccessibilityTrusted ? "已授权 ✅" : "未授权 ⚠️")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !PermissionManager.shared.isAccessibilityTrusted {
                Button("前往系统设置授权") {
                    PermissionManager.shared.openSystemPreferencesAccessibilityPane()
                }
            }
        }
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - 应用快捷启动

struct AppLaunchSettingsView: View {
    @ObservedObject var launcher = AppLauncher.shared
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(launcher.bindings) { binding in
                    HStack {
                        Image(nsImage: launcher.icon(forAppPath: binding.appBundlePath))
                            .resizable().frame(width: 24, height: 24)
                        Text(binding.appName)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name(binding.hotkeyName))
                        Button(role: .destructive) {
                            launcher.removeBinding(binding)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Button("+ 添加应用") { showingAppPicker = true }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(isPresented: $showingAppPicker)
        }
    }
}

struct AppPickerView: View {
    @Binding var isPresented: Bool
    @State private var apps: [(name: String, path: String)] = []
    @State private var searchText = ""

    var filtered: [(name: String, path: String)] {
        searchText.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack {
            TextField("搜索应用", text: $searchText)
                .padding(.bottom, 4)
            List(filtered, id: \.path) { app in
                HStack {
                    Image(nsImage: AppLauncher.shared.icon(forAppPath: app.path))
                        .resizable().frame(width: 20, height: 20)
                    Text(app.name)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    AppLauncher.shared.addBinding(appName: app.name, appBundlePath: app.path)
                    isPresented = false
                }
            }
            Button("取消") { isPresented = false }
        }
        .padding()
        .frame(width: 400, height: 400)
        .onAppear {
            apps = AppLauncher.shared.scanInstalledApplications()
        }
    }
}

// MARK: - 翻译设置

struct TranslationSettingsView: View {
    @State private var openaiKey: String = ""
    @State private var deeplKey: String = ""
    @State private var settings = TranslationSettings.loadCurrent()
    @State private var showSavedConfirmation = false

    var body: some View {
        Form {
            // 服务商用下拉菜单而不是分段控件,方便以后加更多服务商(Google/Azure/...)而不挤爆界面。
            // 只有这里选中的服务商会在实际翻译时被调用,另一家的配置存在本地但不会生效。
            Picker("翻译服务商", selection: $settings.provider) {
                ForEach(TranslationProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.menu)

            Text("当前生效: \(settings.provider.displayName) —— 只有这一个服务商的配置会被实际调用")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // 一个快捷键覆盖两种场景:有划词就直接翻译,没划词就弹出空白输入框手动翻译
            Text("全局快捷键(通用,与服务商无关)").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("翻译(有划词自动翻译 / 无划词手动输入)")
                Spacer()
                KeyboardShortcuts.Recorder(for: .translateSelection)
            }

            Picker("翻译窗口外观", selection: $settings.panelAppearanceMode) {
                ForEach(PanelAppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // 语言配置两家服务商共用一套,不再分开配置;弹窗里也能临时切换成任意其它语言,
            // 这里配的是"默认"的那一对
            Text("默认翻译语言(两个服务商共用)").font(.caption).foregroundStyle(.secondary)
            Picker("主语言(划词是外语时,翻成这个)", selection: $settings.primaryLanguageCode) {
                ForEach(SupportedLanguage.options, id: \.code) { option in
                    Text(option.label).tag(option.code)
                }
            }
            Picker("备语言(划词是主语言时,翻成这个)", selection: $settings.secondaryLanguageCode) {
                ForEach(SupportedLanguage.options, id: \.code) { option in
                    Text(option.label).tag(option.code)
                }
            }

            Divider()

            switch settings.provider {
            case .openai:
                openAISection
            case .deepl:
                deepLSection
            case .ollama:
                ollamaSection
            }

            Divider()

            HStack {
                Button("保存设置") {
                    persist()
                    showSavedConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showSavedConfirmation = false
                    }
                }
                .keyboardShortcut("s", modifiers: .command)

                if showSavedConfirmation {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            openaiKey = KeychainHelper.loadAPIKey(for: .openai) ?? ""
            deeplKey = KeychainHelper.loadAPIKey(for: .deepl) ?? ""
        }
    }

    @ViewBuilder
    private var openAISection: some View {
        SecureField("OpenAI API Key", text: $openaiKey)

        Picker("模型", selection: $settings.model) {
            Text("GPT-4.1 mini(推荐:速度快、够用、便宜)").tag("gpt-4.1-mini")
            Text("GPT-4.1(质量更高,稍慢)").tag("gpt-4.1")
            Text("GPT-5.4 mini(质量更高,含推理)").tag("gpt-5.4-mini")
            Text("GPT-5.4(旗舰,最高质量,较慢较贵)").tag("gpt-5.4")
        }

        VStack(alignment: .leading) {
            Text("自定义翻译 Prompt(只负责风格/格式规则,不控制翻译方向)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $settings.customSystemPrompt)
                .frame(height: 100)
        }
    }

    @ViewBuilder
    private var deepLSection: some View {
        SecureField("DeepL API Key", text: $deeplKey)
        Text("免费版(Key 以 :fx 结尾)和付费版会自动识别,不用手动区分。")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("DeepL 是专业翻译引擎而非大模型,没有流式逐字输出,结果会一次性显示。")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var ollamaSection: some View {
        TextField("Ollama 地址", text: $settings.ollamaBaseURL)
        TextField("模型名(需要先 ollama pull)", text: $settings.ollamaModel)
        Text("跑在你自己电脑上的本地模型,完全免费、不需要联网、不需要 API Key。")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("需要先装好 Ollama(ollama.com)并执行 ollama pull \(settings.ollamaModel) 把模型拉下来,再启动 ollama serve。")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("模型翻译质量取决于你选的本地模型大小,小模型速度快但翻译质量通常不如云端的 GPT/DeepL。")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// 点"保存设置"时统一落盘:非敏感配置存本地 JSON,两个 API Key 分别存各自的 Keychain 条目
    private func persist() {
        settings.save()
        KeychainHelper.saveAPIKey(openaiKey, for: .openai)
        KeychainHelper.saveAPIKey(deeplKey, for: .deepl)
    }
}

// MARK: - 关于

struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "character.bubble")
                .font(.system(size: 40))
            Text("MenuBar Translator").font(.headline)
            Text("v0.1.0").font(.caption).foregroundStyle(.secondary)
            Text("全局快捷键启动应用 + AI 划词翻译")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
