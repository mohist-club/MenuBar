import AppKit

final class TranslationFlowCoordinator {
    static let shared = TranslationFlowCoordinator()
    private init() {}

    private var currentPanel: FloatingTranslationPanel?

    /// 唯一入口:有划词内容就直接翻译;没有划词(或取不到)就弹出空白输入框等待手动输入。
    func trigger() {
        let mouseLocation = TextCaptureService.shared.currentMouseLocation()

        TextCaptureService.shared.captureSelectedText { [weak self] text in
            guard let self else { return }
            let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let panel = self.makePanel()
            if trimmed.isEmpty {
                panel.state.sourceText = ""
                panel.state.sourceLanguageIsAutomatic = true
                panel.state.isManualMode = true
                panel.showCentered()
                self.currentPanel = panel
                panel.focusInput()
                // 手动模式:不自动翻译,等用户输完按 Enter
            } else {
                panel.state.sourceText = trimmed
                panel.state.sourceLanguageIsAutomatic = true
                panel.state.isManualMode = false
                panel.show(near: mouseLocation)
                self.currentPanel = panel
                let settings = TranslationSettings.loadCurrent()
                self.translate(in: panel, targetLanguageCode: LanguageDetector.defaultTargetLanguageCode(
                    for: trimmed, settings: settings
                ))
            }
        }
    }

    private func makePanel() -> FloatingTranslationPanel {
        currentPanel?.close()

        let panel = FloatingTranslationPanel()
        var settings = TranslationSettings.loadCurrent()
        let preferences = AppPreferencesStore.shared.values
        let availableProviders = settings.availableConfiguredProviders()
        if !availableProviders.contains(settings.provider), let fallback = availableProviders.first {
            settings.provider = fallback
            settings.save()
        }
        panel.state.selectedProvider = settings.provider
        panel.state.availableProviders = availableProviders
        panel.applyAppearance(mode: preferences.appearanceMode)

        panel.onTranslateRequested = { [weak self, weak panel] in
            guard let self, let panel else { return }
            let text = panel.state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let settings = TranslationSettings.loadCurrent()
            self.translate(
                in: panel,
                targetLanguageCode: LanguageDetector.defaultTargetLanguageCode(for: text, settings: settings),
                detectSourceLanguage: panel.state.sourceLanguageIsAutomatic
            )
        }
        panel.onSelectProvider = { [weak self, weak panel] provider in
            guard let self, let panel else { return }
            self.selectProvider(provider, in: panel)
        }
        panel.onPickTargetLanguage = { [weak self, weak panel] code in
            guard let self, let panel else { return }
            self.translate(
                in: panel,
                targetLanguageCode: code,
                detectSourceLanguage: panel.state.sourceLanguageIsAutomatic
            )
        }
        panel.onPickSourceLanguage = { [weak panel] code in
            panel?.state.sourceLanguageCode = code
            panel?.state.sourceLanguageIsAutomatic = false
        }
        panel.onSwapLanguages = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.swapLanguages(in: panel)
        }
        panel.onOpenGoogleAI = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.openGoogleAI(for: panel.state.sourceText, targetLanguageCode: panel.state.targetLanguageCode)
        }
        return panel
    }

    /// 底部服务菜单只会传入已经配置的服务。选择后立即持久化；若当前已有
    /// 原文，则用新服务重新翻译，便于直接比较结果和速度。
    private func selectProvider(_ provider: TranslationProvider, in panel: FloatingTranslationPanel) {
        guard panel.state.availableProviders.contains(provider) else { return }
        var settings = TranslationSettings.loadCurrent()
        guard settings.provider != provider else { return }
        settings.provider = provider
        settings.save()
        panel.state.selectedProvider = provider

        let text = panel.state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            translate(
                in: panel,
                targetLanguageCode: panel.state.targetLanguageCode,
                detectSourceLanguage: panel.state.sourceLanguageIsAutomatic
            )
        }
    }

    private func translate(
        in panel: FloatingTranslationPanel,
        targetLanguageCode: String,
        detectSourceLanguage: Bool = true
    ) {
        let text = panel.state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let settings = TranslationSettings.loadCurrent()
        panel.state.targetLanguageCode = targetLanguageCode
        if detectSourceLanguage {
            let detected = LanguageDetector.detectedLanguageCode(text)
            // 识别不出具体是中/日/韩时,按配置的备语言展示。
            panel.state.sourceLanguageCode = detected.isEmpty ? settings.secondaryLanguageCode : detected
            panel.state.sourceLanguageIsAutomatic = true
        }
        panel.state.translatedText = ""
        panel.state.errorMessage = nil
        panel.state.isLoading = true
        let translationID = UUID()
        panel.state.activeTranslationID = translationID

        let onToken: (String) -> Void = { [weak panel] token in
            guard panel?.state.activeTranslationID == translationID else { return }
            panel?.state.translatedText += token
        }
        let onComplete: (Error?) -> Void = { [weak panel] error in
            guard panel?.state.activeTranslationID == translationID else { return }
            panel?.state.isLoading = false
            if let error {
                panel?.state.errorMessage = error.localizedDescription
            }
        }

        switch settings.provider {
        case .zhipu, .openai, .groq:
            TranslationService.shared.translateStreaming(
                text: text, settings: settings, provider: settings.provider,
                targetLanguageCode: targetLanguageCode,
                onToken: onToken, onComplete: onComplete
            )
        case .deepl:
            DeepLService.shared.translate(
                text: text, settings: settings, targetLanguageCode: targetLanguageCode,
                onToken: onToken, onComplete: onComplete
            )
        case .ollama:
            OllamaService.shared.translateStreaming(
                text: text, settings: settings, targetLanguageCode: targetLanguageCode,
                onToken: onToken, onComplete: onComplete
            )
        case .google:
            GoogleAIService.shared.translate(
                text: text, settings: settings, targetLanguageCode: targetLanguageCode,
                onToken: onToken, onComplete: onComplete
            )
        }
    }

    /// 交换当前两侧文本与语种。已有译文时不额外消耗一次 API 请求；交换后的右侧内容
    /// 就是原始文本,用户修改左侧或切换目标语言时再正常触发翻译。
    private func swapLanguages(in panel: FloatingTranslationPanel) {
        let source = panel.state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translated = panel.state.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !translated.isEmpty, !panel.state.isLoading else { return }

        let oldSourceLanguage = panel.state.sourceLanguageCode
        panel.state.sourceText = translated
        panel.state.translatedText = source
        panel.state.sourceLanguageCode = panel.state.targetLanguageCode
        panel.state.targetLanguageCode = oldSourceLanguage
        panel.state.sourceLanguageIsAutomatic = false
        panel.state.errorMessage = nil
    }

    private func openGoogleAI(for sourceText: String, targetLanguageCode: String) {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "udm", value: "50"),
            URLQueryItem(
                name: "q",
                value: "请将下面的内容翻译为\(SupportedLanguage.label(for: targetLanguageCode))：\n\(trimmed)"
            )
        ]
        guard let url = components?.url else { return }
        NSWorkspace.shared.open(url)
    }
}
