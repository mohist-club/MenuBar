import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

private enum SettingsDestination: String, CaseIterable, Identifiable {
    case general, shortcuts, services, about
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .services: return "globe"
        case .about: return "info.circle"
        }
    }

    func title(_ language: InterfaceLanguage) -> String {
        switch self {
        case .general: return PoptroText.value("通用", "General", language: language)
        case .shortcuts: return PoptroText.value("快捷键", "Shortcuts", language: language)
        case .services: return PoptroText.value("服务", "Services", language: language)
        case .about: return PoptroText.value("关于", "About", language: language)
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var preferences = AppPreferencesStore.shared
    @State private var destination: SettingsDestination? = .general

    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }

    var body: some View {
        NavigationSplitView {
            List(SettingsDestination.allCases, selection: $destination) { item in
                Label(item.title(language), systemImage: item.icon).tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 168, ideal: 188, max: 220)
        } detail: {
            Group {
                switch destination ?? .general {
                case .general: GeneralSettingsView()
                case .shortcuts: ShortcutSettingsView()
                case .services: ServicesSettingsView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(preferences.values.appearanceMode == .dark ? .dark :
            preferences.values.appearanceMode == .light ? .light : nil)
    }
}

private struct SettingsPageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var preferences = AppPreferencesStore.shared
    @State private var launchAtLogin: Bool
    @State private var accessibilityGranted = PermissionManager.shared.isAccessibilityTrusted
    @State private var launchAtLoginError: String?

    init() { _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled) }
    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(
                title: t("通用", "General"),
                subtitle: t("设置 Poptro 的界面、窗口效果与系统行为。", "Configure Poptro's interface, window effects and system behavior.")
            )
            Form {
                Section(t("外观与语言", "Appearance & Language")) {
                    Picker(t("界面语言", "Interface Language"), selection: $preferences.values.interfaceLanguage) {
                        ForEach(InterfaceLanguage.allCases) { Text($0.nativeDisplayName).tag($0) }
                    }
                    Picker(t("外观", "Appearance"), selection: $preferences.values.appearanceMode) {
                        ForEach(PanelAppearanceMode.allCases) { Text($0.localizedName(language: language)).tag($0) }
                    }
                    Toggle(t("窗口玻璃效果", "Window Glass Effect"), isOn: $preferences.values.glassEffectEnabled)
                    HStack {
                        Text(t("效果强度", "Effect Intensity"))
                        Slider(value: $preferences.values.glassTransparency, in: 0.15...0.85, step: 0.05)
                        Text("\(Int((preferences.values.glassTransparency * 100).rounded()))%")
                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
                    }
                    .disabled(!preferences.values.glassEffectEnabled)
                    Text(t(
                        "外观设置适用于所有 Poptro 窗口，包括设置。macOS 26/27 使用系统液态玻璃，旧系统使用原生毛玻璃。",
                        "Appearance applies to every Poptro window, including Settings. macOS 26/27 uses native Liquid Glass, with native vibrancy on older systems."
                    )).font(.caption).foregroundStyle(.secondary)
                }
                Section(t("系统", "System")) {
                    Toggle(t("开机自动启动", "Launch at Login"), isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { updateLaunchAtLogin($0) }
                    if let launchAtLoginError { Text(launchAtLoginError).font(.caption).foregroundStyle(.red) }
                    LabeledContent(t("辅助功能", "Accessibility")) {
                        Label(
                            accessibilityGranted ? t("已授权", "Allowed") : t("未授权", "Not Allowed"),
                            systemImage: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        ).foregroundStyle(accessibilityGranted ? .green : .orange)
                    }
                    HStack {
                        Button(t("重新检测", "Check Again")) { accessibilityGranted = PermissionManager.shared.isAccessibilityTrusted }
                        if !accessibilityGranted {
                            Button(t("前往系统设置授权", "Open System Settings")) { PermissionManager.shared.openSystemPreferencesAccessibilityPane() }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding(24)
        .onAppear { accessibilityGranted = PermissionManager.shared.isAccessibilityTrusted }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    private func t(_ zh: String, _ en: String) -> String { PoptroText.value(zh, en, language: language) }
}

struct ShortcutSettingsView: View {
    @ObservedObject private var preferences = AppPreferencesStore.shared
    @ObservedObject private var launcher = AppLauncher.shared
    @AppStorage("translateShortcutEnabled") private var translateShortcutEnabled = true
    @State private var showingAppPicker = false
    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(
                title: t("快捷键", "Shortcuts"),
                subtitle: t("设置全局翻译快捷键和应用启动快捷键。", "Configure global translation and app launch shortcuts.")
            )
            Form {
                Section(t("内置快捷键", "Built-in Shortcut")) {
                    HStack(spacing: 12) {
                        Image(systemName: "character.cursor.ibeam").frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("划词翻译", "Translate Selection"))
                            Text(t("翻译当前选中的文字", "Translate the currently selected text"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ShortcutRecorderView(name: .translateSelection).frame(width: 120)
                        Toggle("", isOn: $translateShortcutEnabled).labelsHidden()
                            .onChange(of: translateShortcutEnabled) { HotkeyManager.shared.setTranslationEnabled($0) }
                        Label(t("内置", "Built-in"), systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section(t("应用快捷键", "App Shortcuts")) {
                    ForEach(launcher.bindings) { binding in
                        HStack(spacing: 12) {
                            Image(nsImage: launcher.icon(forAppPath: binding.appBundlePath)).resizable().frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(binding.appName)
                                Text(t("打开应用", "Open App")).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ShortcutRecorderView(name: KeyboardShortcuts.Name(binding.hotkeyName)).frame(width: 120)
                            Toggle("", isOn: Binding(
                                get: { launcher.bindings.first(where: { $0.id == binding.id })?.isEnabled ?? false },
                                set: { launcher.setEnabled($0, for: binding) }
                            )).labelsHidden()
                            Button(role: .destructive) { launcher.removeBinding(binding) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).help(t("删除快捷键", "Remove Shortcut"))
                        }
                    }
                    Button { showingAppPicker = true } label: { Label(t("添加应用快捷键", "Add App Shortcut"), systemImage: "plus") }
                }
            }
            .formStyle(.grouped)
        }
        .padding(24)
        .sheet(isPresented: $showingAppPicker) { AppPickerView(isPresented: $showingAppPicker) }
    }
    private func t(_ zh: String, _ en: String) -> String { PoptroText.value(zh, en, language: language) }
}

struct AppPickerView: View {
    @ObservedObject private var preferences = AppPreferencesStore.shared
    @Binding var isPresented: Bool
    @State private var apps: [(name: String, path: String)] = []
    @State private var searchText = ""
    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }
    private var filtered: [(name: String, path: String)] {
        searchText.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField(t("搜索应用", "Search Apps"), text: $searchText).textFieldStyle(.roundedBorder)
            List(filtered, id: \.path) { app in
                HStack {
                    Image(nsImage: AppLauncher.shared.icon(forAppPath: app.path)).resizable().frame(width: 24, height: 24)
                    Text(app.name); Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    AppLauncher.shared.addBinding(appName: app.name, appBundlePath: app.path)
                    isPresented = false
                }
            }
            HStack { Spacer(); Button(t("取消", "Cancel")) { isPresented = false } }
        }
        .padding(16).frame(width: 420, height: 440)
        .onAppear { apps = AppLauncher.shared.scanInstalledApplications() }
    }
    private func t(_ zh: String, _ en: String) -> String { PoptroText.value(zh, en, language: language) }
}

struct ServicesSettingsView: View {
    @ObservedObject private var preferences = AppPreferencesStore.shared
    @State private var settings = TranslationSettings.loadCurrent()
    @State private var apiKeys: [TranslationProvider: String] = [:]
    @State private var discoveredModels: [TranslationProvider: [String]] = [:]
    @State private var isLoadingModels = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var showSaved = false
    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("服务", "Services")).font(.title2.weight(.semibold)).padding(.horizontal, 12).padding(.top, 16)
                Text(t("选择当前使用的翻译服务。", "Choose the active translation service."))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                List(TranslationProvider.allCases, selection: $settings.provider) { provider in
                    HStack(spacing: 10) {
                        Image(systemName: providerIcon(provider)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.localizedDisplayName(language: language))
                            Text(providerSubtitle(provider)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if provider == settings.provider { Circle().fill(.green).frame(width: 7, height: 7) }
                    }.tag(provider)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 210, idealWidth: 230, maxWidth: 260)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsPageHeader(
                            title: settings.provider.localizedDisplayName(language: language),
                            subtitle: providerDetailSubtitle(settings.provider)
                        )
                        providerForm
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(24)
                }
                Divider()
                HStack(spacing: 12) {
                    if isLoadingModels { ProgressView().controlSize(.small) }
                    if let statusMessage {
                        Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(statusIsError ? .red : .green).lineLimit(2)
                    } else {
                        Text(t("所有配置仅保存在当前 Mac。", "All configuration stays on this Mac."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(t("测试连接", "Test Connection")) { testConnection() }.disabled(isLoadingModels)
                    Button(t("保存", "Save")) { persist() }.keyboardShortcut("s", modifiers: .command)
                    if showSaved { Text(t("已保存", "Saved")).font(.caption).foregroundStyle(.green) }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .frame(minWidth: 520)
        }
        .onAppear { loadLocalValues() }
        .onChange(of: settings.provider) { _ in
            settings.save(); statusMessage = nil
            if discoveredModels[settings.provider] == nil, settings.provider.supportsRemoteModelDiscovery { refreshModels() }
        }
    }

    @ViewBuilder private var providerForm: some View {
        Form {
            if settings.provider != .ollama {
                Section(t("连接", "Connection")) {
                    SecureField(t("API Key", "API Key"), text: keyBinding(for: settings.provider))
                    if settings.provider == .zhipu {
                        LabeledContent(t("接口地址", "Endpoint"), value: "open.bigmodel.cn/api/paas/v4")
                    } else if settings.provider == .groq {
                        LabeledContent(t("接口地址", "Endpoint"), value: "api.groq.com/openai/v1")
                    } else if settings.provider == .google {
                        LabeledContent(t("接口地址", "Endpoint"), value: "generativelanguage.googleapis.com/v1beta")
                    } else if settings.provider == .deepl {
                        LabeledContent(t("API 类型", "API Type"), value: t("自动识别 Free / Pro", "Detect Free / Pro automatically"))
                    }
                }
            } else {
                Section(t("连接", "Connection")) {
                    LabeledContent(t("服务名称", "Service Name"), value: "Ollama")
                    TextField("Base URL", text: $settings.ollamaBaseURL)
                    LabeledContent(t("请求超时", "Timeout"), value: t("60 秒", "60 seconds"))
                }
            }

            if settings.provider != .deepl {
                Section(t("模型", "Model")) {
                    Picker(t("模型", "Model"), selection: selectedModelBinding) {
                        ForEach(modelOptions, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Button { refreshModels() } label: {
                            Label(t("读取支持的模型", "Load Supported Models"), systemImage: "arrow.clockwise")
                        }
                        .disabled(isLoadingModels || (settings.provider.requiresAPIKey && keyBindingValue(settings.provider).isEmpty))
                        Text(t("模型列表来自服务商接口。", "Models are loaded from the provider API."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section(t("翻译语言", "Translation Languages")) {
                LabeledContent(t("源语言", "Source Language"), value: t("自动检测", "Auto Detect"))
                Picker(t("目标语言", "Target Language"), selection: $settings.primaryLanguageCode) {
                    ForEach(SupportedLanguage.options, id: \.code) { option in
                        Text(SupportedLanguage.localizedLabel(for: option.code, language: language)).tag(option.code)
                    }
                }
                Picker(t("备用语言", "Secondary Language"), selection: $settings.secondaryLanguageCode) {
                    ForEach(SupportedLanguage.options, id: \.code) { option in
                        Text(SupportedLanguage.localizedLabel(for: option.code, language: language)).tag(option.code)
                    }
                }
            }

            if settings.provider != .deepl {
                DisclosureGroup(t("高级", "Advanced")) {
                    TextEditor(text: $settings.customSystemPrompt).frame(minHeight: 110)
                    Text(t("翻译方向由 Poptro 自动判断；提示词只控制风格与格式。", "Poptro detects direction automatically; this prompt controls style and formatting only."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var modelOptions: [String] {
        let current = settings.model(for: settings.provider)
        var values = discoveredModels[settings.provider] ?? ProviderModelService.fallbackModels(for: settings.provider)
        if !current.isEmpty, !values.contains(current) { values.insert(current, at: 0) }
        return values
    }
    private var selectedModelBinding: Binding<String> {
        Binding(get: { settings.model(for: settings.provider) }, set: { settings.setModel($0, for: settings.provider) })
    }
    private func keyBinding(for provider: TranslationProvider) -> Binding<String> {
        Binding(get: { apiKeys[provider, default: ""] }, set: { apiKeys[provider] = $0 })
    }
    private func keyBindingValue(_ provider: TranslationProvider) -> String { apiKeys[provider, default: ""] }

    private func loadLocalValues() {
        for provider in TranslationProvider.allCases where provider.requiresAPIKey {
            apiKeys[provider] = KeychainHelper.loadAPIKey(for: provider) ?? ""
        }
    }
    private func persist() {
        settings.save()
        for provider in TranslationProvider.allCases where provider.requiresAPIKey {
            KeychainHelper.saveAPIKey(apiKeys[provider, default: ""], for: provider)
        }
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { showSaved = false }
    }
    private func refreshModels() {
        persist()
        let provider = settings.provider
        isLoadingModels = true; statusMessage = t("正在读取模型…", "Loading models…"); statusIsError = false
        Task {
            do {
                let models = try await ProviderModelService.fetchModels(for: provider, settings: settings)
                await MainActor.run {
                    discoveredModels[provider] = models
                    if let first = models.first, !models.contains(settings.model(for: provider)) { settings.setModel(first, for: provider) }
                    isLoadingModels = false
                    statusMessage = t("已读取 \(models.count) 个可用模型", "Loaded \(models.count) available models")
                }
            } catch {
                await MainActor.run { isLoadingModels = false; statusIsError = true; statusMessage = error.localizedDescription }
            }
        }
    }
    private func testConnection() {
        persist()
        let provider = settings.provider
        isLoadingModels = true; statusIsError = false; statusMessage = t("正在测试连接…", "Testing connection…")
        Task {
            do {
                try await ProviderModelService.testConnection(for: provider, settings: settings)
                await MainActor.run { isLoadingModels = false; statusMessage = t("连接成功", "Connected") }
            } catch {
                await MainActor.run { isLoadingModels = false; statusIsError = true; statusMessage = error.localizedDescription }
            }
        }
    }

    private func providerIcon(_ provider: TranslationProvider) -> String {
        switch provider {
        case .zhipu: return "sparkles"
        case .openai: return "brain.head.profile"
        case .deepl: return "character.book.closed"
        case .groq: return "bolt.horizontal.circle"
        case .google: return "g.circle"
        case .ollama: return "desktopcomputer"
        }
    }
    private func providerSubtitle(_ provider: TranslationProvider) -> String {
        switch provider {
        case .zhipu: return t("免费模型 · 默认", "Free model · Default")
        case .openai: return t("OpenAI 模型", "OpenAI models")
        case .deepl: return t("专业翻译服务", "Professional translation")
        case .groq: return t("高速推理服务", "Fast inference")
        case .google: return t("Gemini 模型", "Gemini models")
        case .ollama: return t("本机离线模型", "On-device models")
        }
    }
    private func providerDetailSubtitle(_ provider: TranslationProvider) -> String {
        if provider == .zhipu { return t("默认使用免费的 GLM-4-Flash-250414，也可以读取并选择其他可用模型。", "Uses the free GLM-4-Flash-250414 by default; you can load and select other available models.") }
        if provider == .ollama { return t("连接本机 Ollama，并读取已经安装的模型。", "Connect to local Ollama and load installed models.") }
        return t("配置服务连接、模型和翻译语言。", "Configure the service connection, model and translation languages.")
    }
    private func t(_ zh: String, _ en: String) -> String { PoptroText.value(zh, en, language: language) }
}

struct AboutView: View {
    @ObservedObject private var preferences = AppPreferencesStore.shared
    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsPageHeader(title: t("关于", "About"), subtitle: t("版本信息、更新与项目链接。", "Version, updates and project links."))
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Poptro").font(.headline)
                            Text(t("版本", "Version") + " " + version).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(t("检查更新…", "Check for Updates…")) { AutoUpdater.checkForUpdates() }
                    }
                }
                Section(t("更新", "Updates")) {
                    Toggle(t("自动检查更新", "Automatically Check for Updates"), isOn: $preferences.values.automaticUpdateChecks)
                    LabeledContent(t("更新来源", "Update Source"), value: "GitHub Releases")
                }
                Section(t("链接", "Links")) {
                    Link(destination: URL(string: "https://github.com/mohist-club/Poptro/releases")!) {
                        HStack { Label(t("GitHub 开源地址", "GitHub Releases"), systemImage: "chevron.left.forwardslash.chevron.right"); Spacer(); Image(systemName: "arrow.up.right.square") }
                    }
                    Link(destination: URL(string: "https://moaclab.com/t/topic/2638")!) {
                        HStack { Label(t("网站社区", "Community"), systemImage: "globe"); Spacer(); Image(systemName: "arrow.up.right.square") }
                    }
                }
            }.formStyle(.grouped)
        }.padding(24)
    }
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
    private func t(_ zh: String, _ en: String) -> String { PoptroText.value(zh, en, language: language) }
}
