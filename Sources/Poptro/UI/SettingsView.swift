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
    @State private var settings: TranslationSettings
    @State private var selectedProvider: TranslationProvider
    @State private var apiKeys: [TranslationProvider: String] = [:]
    @State private var discoveredModels: [TranslationProvider: [String]] = [:]
    @State private var benchmarks: [TranslationProvider: ProviderBenchmarkResult] = [:]
    @State private var isLoadingModels = false
    @State private var isBenchmarking = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var showSaved = false
    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }

    init() {
        let current = TranslationSettings.loadCurrent()
        _settings = State(initialValue: current)
        _selectedProvider = State(initialValue: current.provider)
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("翻译服务", "Translation Services"))
                    .font(.title2.weight(.semibold)).padding(.horizontal, 12).padding(.top, 16)
                Text(t("选择服务进行查看；默认服务仅可设置一个。", "Select a service to inspect; only one can be the default."))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                List(TranslationProvider.allCases, selection: $selectedProvider) { provider in
                    providerRow(provider).tag(provider)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        providerHeader
                        providerForm
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(24)
                }
                Divider()
                HStack(spacing: 12) {
                    if isLoadingModels || isBenchmarking { ProgressView().controlSize(.small) }
                    if let statusMessage {
                        Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(statusIsError ? .red : .green).lineLimit(2)
                    } else {
                        Text(t("所有配置仅保存在当前 Mac。", "All configuration stays on this Mac."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(t("保存", "Save")) { persist() }.keyboardShortcut("s", modifiers: .command)
                    if showSaved { Text(t("已保存", "Saved")).font(.caption).foregroundStyle(.green) }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
            .frame(minWidth: 520)
        }
        .onAppear { loadLocalValues() }
        .onChange(of: selectedProvider) { _ in
            statusMessage = nil
            statusIsError = false
        }
    }

    private func providerRow(_ provider: TranslationProvider) -> some View {
        HStack(spacing: 10) {
            Image(systemName: providerIcon(provider)).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(providerListName(provider)).lineLimit(1)
                    if provider == settings.provider {
                        Label(t("默认", "Default"), systemImage: "star.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(recommendedModel(for: provider))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Circle().fill(statusColor(for: provider)).frame(width: 7, height: 7)
            Text(providerStatusText(provider))
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private var providerHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsPageHeader(
                title: selectedProvider.localizedDisplayName(language: language),
                subtitle: providerDetailSubtitle(selectedProvider)
            )
            HStack(spacing: 12) {
                Circle().fill(statusColor(for: selectedProvider)).frame(width: 9, height: 9)
                Text(providerStatusLongText(selectedProvider)).font(.callout)
                Divider().frame(height: 18)
                Text(t("当前默认：", "Current default: ") + settings.provider.localizedDisplayName(language: language))
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                if selectedProvider == settings.provider {
                    Label(t("默认服务", "Default Service"), systemImage: "star.fill")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Button(t("设为默认服务", "Set as Default")) { setDefaultProvider() }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.09), lineWidth: 0.7))
        }
    }

    @ViewBuilder private var providerForm: some View {
        Form {
            if selectedProvider != .ollama {
                Section(t("连接", "Connection")) {
                    SecureField(t("API Key", "API Key"), text: keyBinding(for: selectedProvider))
                    if selectedProvider == .zhipu {
                        LabeledContent(t("接口地址", "Endpoint"), value: "open.bigmodel.cn/api/paas/v4")
                    } else if selectedProvider == .groq {
                        LabeledContent(t("接口地址", "Endpoint"), value: "api.groq.com/openai/v1")
                    } else if selectedProvider == .google {
                        LabeledContent(t("接口地址", "Endpoint"), value: "generativelanguage.googleapis.com/v1beta")
                    } else if selectedProvider == .deepl {
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

            if selectedProvider != .deepl {
                Section(t("模型", "Model")) {
                    Picker(t("模型", "Model"), selection: selectedModelBinding) {
                        ForEach(modelOptions, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Button { refreshModels() } label: {
                            Label(t("读取支持的模型", "Load Supported Models"), systemImage: "arrow.clockwise")
                        }
                        .disabled(isLoadingModels || (selectedProvider.requiresAPIKey && keyBindingValue(selectedProvider).isEmpty))
                        Text(t("推荐：", "Recommended: ") + recommendedModel(for: selectedProvider))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section(t("性能测试记录", "Performance Test")) {
                if let result = benchmarks[selectedProvider], result.isSuccessful {
                    LabeledContent(t("当前模型", "Model"), value: result.model)
                    LabeledContent(t("首字耗时", "Time to First Token"), value: durationText(result.firstTokenSeconds))
                    LabeledContent(t("完整耗时", "Total Time"), value: durationText(result.totalSeconds))
                    LabeledContent(t("输出速度", "Output Speed"), value: speedText(result.charactersPerSecond))
                    Label(
                        t("上次测速：", "Last tested: ") + formattedDate(result.testedAt),
                        systemImage: "checkmark.circle.fill"
                    ).font(.caption).foregroundStyle(.secondary)
                } else if let result = benchmarks[selectedProvider], let error = result.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    Text(t("尚未测速。", "Not tested yet."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button(t("验证并测速", "Verify & Test Speed")) { benchmarkSelectedProvider() }
                        .disabled(isBenchmarking || isLoadingModels)
                    Text(t(
                        "测速会实际发送一段短文本，并消耗少量额度。",
                        "The speed test sends a short translation and uses a small amount of quota."
                    )).font(.caption).foregroundStyle(.secondary)
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

            if selectedProvider != .deepl {
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
        let current = settings.model(for: selectedProvider)
        var values = discoveredModels[selectedProvider] ?? ProviderModelService.fallbackModels(for: selectedProvider)
        if !current.isEmpty, !values.contains(current) { values.insert(current, at: 0) }
        return values
    }
    private var selectedModelBinding: Binding<String> {
        Binding(get: { settings.model(for: selectedProvider) }, set: { settings.setModel($0, for: selectedProvider) })
    }
    private func keyBinding(for provider: TranslationProvider) -> Binding<String> {
        Binding(get: { apiKeys[provider, default: ""] }, set: { apiKeys[provider] = $0 })
    }
    private func keyBindingValue(_ provider: TranslationProvider) -> String { apiKeys[provider, default: ""] }

    private func loadLocalValues() {
        for provider in TranslationProvider.allCases where provider.requiresAPIKey {
            apiKeys[provider] = KeychainHelper.loadAPIKey(for: provider) ?? ""
        }
        benchmarks = ProviderBenchmarkStore.load()
    }
    private func persist(showConfirmation: Bool = true) {
        for provider in TranslationProvider.allCases where provider.requiresAPIKey {
            let key = apiKeys[provider, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty {
                KeychainHelper.deleteAPIKey(for: provider)
                settings.configuredProviders.remove(provider)
            } else {
                KeychainHelper.saveAPIKey(key, for: provider)
                settings.configuredProviders.insert(provider)
            }
        }
        if selectedProvider == .ollama {
            settings.configuredProviders.insert(.ollama)
        }
        settings.save()
        if showConfirmation {
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { showSaved = false }
        }
    }
    private func setDefaultProvider() {
        settings.provider = selectedProvider
        persist(showConfirmation: false)
        statusIsError = false
        statusMessage = t("已设为默认翻译服务", "Default translation service updated")
    }
    private func refreshModels() {
        persist(showConfirmation: false)
        let provider = selectedProvider
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
    private func benchmarkSelectedProvider() {
        persist(showConfirmation: false)
        let provider = selectedProvider
        isBenchmarking = true
        statusIsError = false
        statusMessage = t("正在执行真实翻译测速…", "Running a real translation speed test…")
        ProviderBenchmarkService.run(provider: provider, settings: settings) { result in
            benchmarks[provider] = result
            isBenchmarking = false
            statusIsError = !result.isSuccessful
            // 失败详情已经显示在“性能测试记录”中，底栏不再重复同一条错误。
            statusMessage = result.isSuccessful
                ? t("连接正常，测速完成", "Connected; speed test complete")
                : nil
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
    private func providerListName(_ provider: TranslationProvider) -> String {
        switch provider {
        case .zhipu: return t("智谱 GLM", "Zhipu GLM")
        case .openai: return "OpenAI"
        case .deepl: return "DeepL"
        case .groq: return "Groq"
        case .google: return "Google AI"
        case .ollama: return t("本地模型", "Local Model")
        }
    }
    private func recommendedModel(for provider: TranslationProvider) -> String {
        switch provider {
        case .zhipu: return "GLM-4-Flash-250414"
        case .openai: return "GPT-4.1 mini"
        case .deepl: return "DeepL API Free"
        case .groq: return "Qwen 3.8 27B"
        case .google: return "Gemini 3.5 Flash-Lite"
        case .ollama: return "Qwen3 8B"
        }
    }
    private func providerDetailSubtitle(_ provider: TranslationProvider) -> String {
        if provider == .zhipu { return t("免费模型服务", "Free model service") }
        if provider == .groq { return t("高速模型推理服务", "High-speed model inference") }
        if provider == .google { return t("Gemini 模型服务", "Gemini model service") }
        if provider == .ollama { return t("连接本机 Ollama，并读取已经安装的模型。", "Connect to local Ollama and load installed models.") }
        return t("配置服务连接、模型和翻译语言。", "Configure the service connection, model and translation languages.")
    }
    private func providerStatusText(_ provider: TranslationProvider) -> String {
        if let result = benchmarks[provider], result.isSuccessful {
            return durationText(result.firstTokenSeconds ?? result.totalSeconds)
        }
        if let result = benchmarks[provider], result.errorMessage != nil {
            return t("需注意", "Attention")
        }
        if provider.requiresAPIKey, keyBindingValue(provider).isEmpty {
            return t("未配置", "Not configured")
        }
        return t("未测速", "Not tested")
    }
    private func providerStatusLongText(_ provider: TranslationProvider) -> String {
        if let result = benchmarks[provider], result.isSuccessful { return t("连接正常", "Connected") }
        if let result = benchmarks[provider], let error = result.errorMessage { return error }
        if provider.requiresAPIKey, keyBindingValue(provider).isEmpty { return t("尚未配置 API Key", "API Key not configured") }
        return t("等待验证与测速", "Waiting for verification and speed test")
    }
    private func statusColor(for provider: TranslationProvider) -> Color {
        if let result = benchmarks[provider] { return result.isSuccessful ? .green : .orange }
        return .secondary.opacity(0.55)
    }
    private func durationText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f %@", value, t("秒", "s"))
    }
    private func speedText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f %@", value, t("字符/秒", "chars/s"))
    }
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                            Text(t("轻量的划词翻译与快捷启动工具", "A lightweight selection translator and app launcher"))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(t("版本", "Version") + " " + version).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section(t("应用信息", "Application Information")) {
                    LabeledContent(t("开发者", "Developer"), value: "Wayne")
                    LabeledContent(t("开源协议", "License"), value: "MIT License")
                    LabeledContent(t("系统要求", "System Requirements"), value: t("macOS 13 或更高版本", "macOS 13 or later"))
                }
                Section(t("更新设置", "Update Settings")) {
                    Toggle(t("自动检查更新", "Automatically Check for Updates"), isOn: $preferences.values.automaticUpdateChecks)
                    LabeledContent(t("更新来源", "Update Source"), value: "GitHub Releases")
                    HStack {
                        Button(t("检查更新…", "Check for Updates…")) { AutoUpdater.checkForUpdates() }
                        Spacer()
                    }
                }
                Section(t("相关链接", "Links")) {
                    Link(destination: URL(string: "https://github.com/mohist-club/Poptro/releases")!) {
                        HStack {
                            Text(t("GitHub 开源地址", "GitHub Open Source"))
                            Spacer()
                            Text("github.com/mohist-club/Poptro").foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                    Link(destination: URL(string: "https://moaclab.com/t/topic/2638")!) {
                        HStack {
                            Text(t("网站社区", "Community"))
                            Spacer()
                            Text("moaclab.com/t/topic/2638").foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }.formStyle(.grouped)
            HStack(spacing: 7) {
                Image(systemName: "lock.fill")
                Text(t(
                    "API Key 与个人配置仅保存在当前 Mac，并在本地加密。",
                    "API keys and personal settings stay encrypted on this Mac."
                ))
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.top, 8)
            Text("© 2026 Wayne. Poptro is open source software.")
                .font(.caption).foregroundStyle(.tertiary).padding(.horizontal, 18).padding(.top, 8)
        }.padding(24)
    }
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
    private func t(_ zh: String, _ en: String) -> String { PoptroText.value(zh, en, language: language) }
}
