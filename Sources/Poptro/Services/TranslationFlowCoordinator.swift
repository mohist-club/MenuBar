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
        let settings = TranslationSettings.loadCurrent()
        let preferences = AppPreferencesStore.shared.values
        panel.state.providerDisplayName = settings.provider.localizedDisplayName(
            language: preferences.interfaceLanguage
        )
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
        panel.onSwitchProvider = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.switchProvider(in: panel)
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

    /// 顶部"切换翻译引擎"按钮:在已启用的服务商之间循环切换,立即持久化,
    /// 如果当前已经有内容,顺手用新引擎重新翻译一次,方便直接对比效果
    private func switchProvider(in panel: FloatingTranslationPanel) {
        var settings = TranslationSettings.loadCurrent()
        let all = TranslationProvider.allCases
        guard let currentIndex = all.firstIndex(of: settings.provider) else { return }
        settings.provider = all[(currentIndex + 1) % all.count]
        settings.save()

        panel.state.providerDisplayName = settings.provider.localizedDisplayName(
            language: AppPreferencesStore.shared.values.interfaceLanguage
        )

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

        let onToken: (String) -> Void = { [weak panel] token in
            panel?.state.translatedText += token
        }
        let onComplete: (Error?) -> Void = { [weak panel] error in
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
