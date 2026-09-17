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
                panel.state.isManualMode = true
                panel.showCentered()
                self.currentPanel = panel
                panel.focusInput()
                // 手动模式:不自动翻译,等用户输完按 Enter
            } else {
                panel.state.sourceText = trimmed
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
        panel.state.providerDisplayName = settings.provider.displayName
        panel.applyAppearance(mode: settings.panelAppearanceMode)

        panel.onTranslateRequested = { [weak self, weak panel] in
            guard let self, let panel else { return }
            let text = panel.state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let settings = TranslationSettings.loadCurrent()
            self.translate(in: panel, targetLanguageCode: LanguageDetector.defaultTargetLanguageCode(
                for: text, settings: settings
            ))
        }
        panel.onSwitchProvider = { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.switchProvider(in: panel)
        }
        panel.onPickTargetLanguage = { [weak self, weak panel] code in
            guard let self, let panel else { return }
            self.translate(in: panel, targetLanguageCode: code)
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

        panel.state.providerDisplayName = settings.provider.displayName

        let text = panel.state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            translate(in: panel, targetLanguageCode: panel.state.targetLanguageCode)
        }
    }

    private func translate(in panel: FloatingTranslationPanel, targetLanguageCode: String) {
        let text = panel.state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let settings = TranslationSettings.loadCurrent()
        panel.state.targetLanguageCode = targetLanguageCode
        let detected = LanguageDetector.detectedLanguageCode(text)
        // 识别不出具体是中/日/韩(比如英文、法文这类拉丁字母语言),没法精确判断,
        // 按配置的"备语言"展示(通常就是英语,大多数场景下这个猜测是对的)
        panel.state.sourceLanguageCode = detected.isEmpty ? settings.secondaryLanguageCode : detected
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
        case .openai:
            TranslationService.shared.translateStreaming(
                text: text, settings: settings, targetLanguageCode: targetLanguageCode,
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
        }
    }
}
