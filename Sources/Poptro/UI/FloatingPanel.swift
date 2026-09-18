import AppKit
import SwiftUI
import Combine

final class TranslationPanelState: ObservableObject {
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var targetLanguageCode = "EN-US"
    @Published var sourceLanguageCode = "EN-US"
    @Published var sourceLanguageIsAutomatic = true
    @Published var selectedProvider: TranslationProvider = .zhipu
    @Published var availableProviders: [TranslationProvider] = []
    @Published var isPinned = false

    var isManualMode = false
    var activeTranslationID = UUID()

    var statusText: String {
        if isLoading { return "正在翻译…" }
        if errorMessage != nil { return "翻译失败" }
        if translatedText.isEmpty { return "等待输入" }
        return "翻译完成"
    }
}

private final class DraggableBackgroundView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggableBackgroundView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

private struct AdaptiveWindowBackground: View {
    let cornerRadius: CGFloat
    let transparency: Double
    let glassEnabled: Bool

    private var tintOpacity: Double {
        max(0.08, (1 - transparency) * 0.72)
    }

    @ViewBuilder
    var body: some View {
        if !glassEnabled {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        } else {
#if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(
                        .regular.tint(Color(nsColor: .windowBackgroundColor).opacity(tintOpacity)),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            } else {
                legacyBackground
            }
#else
            legacyBackground
#endif
        }
    }

    private var legacyBackground: some View {
        VisualEffectBackground(material: .hudWindow)
            .overlay(
                Color(nsColor: .windowBackgroundColor)
                    .opacity(max(0.03, tintOpacity * 0.55))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct NeutralSurface: ViewModifier {
    let cornerRadius: CGFloat
    let emphasized: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        Color(nsColor: .controlBackgroundColor)
                            .opacity(emphasized ? 0.72 : 0.50)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(emphasized ? 0.13 : 0.085), lineWidth: 0.7)
            )
    }
}

private extension View {
    func neutralSurface(cornerRadius: CGFloat = 9, emphasized: Bool = false) -> some View {
        modifier(NeutralSurface(cornerRadius: cornerRadius, emphasized: emphasized))
    }
}

private struct LanguageSelectorLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title).lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 34)
        .contentShape(Rectangle())
        .neutralSurface(cornerRadius: 9)
    }
}

struct TranslationPanelView: View {
    @ObservedObject var state: TranslationPanelState
    @ObservedObject private var preferences = AppPreferencesStore.shared
    var onTranslateRequested: () -> Void
    var onClear: () -> Void
    var onSelectProvider: (TranslationProvider) -> Void
    var onPickSourceLanguage: (String) -> Void
    var onPickTargetLanguage: (String) -> Void
    var onSwapLanguages: () -> Void
    var onOpenGoogleAI: () -> Void
    var onCopySource: () -> Void
    var onCopyTranslated: () -> Void
    var onTextViewReady: (NSTextView) -> Void

    private let cornerRadius: CGFloat = 22
    private let readingFontSize: CGFloat = 16
    private let readingLineSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().opacity(0.62)
            languageBar
            Divider().opacity(0.62)
            translationContent
            Divider().opacity(0.62)
            statusBar
        }
        .background(AdaptiveWindowBackground(
            cornerRadius: cornerRadius,
            transparency: preferences.values.glassTransparency,
            glassEnabled: preferences.values.glassEffectEnabled
        ))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 0.7)
        )
        .background(
            Button("") { onCopyTranslated() }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
        )
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "command")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 28, height: 28)
                .neutralSurface(cornerRadius: 7)
                .accessibilityHidden(true)

            Text("Poptro")
                .font(.system(size: 13, weight: .semibold))

            Spacer(minLength: 10)

            Button(action: onOpenGoogleAI) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(t("在 Google AI 中查看", "View in Google AI"))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .neutralSurface(cornerRadius: 9, emphasized: true)
            }
            .buttonStyle(.plain)
            .disabled(state.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(t("将原文发送到 Google AI 模式", "Send source text to Google AI Mode"))
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(WindowDragHandle())
        .background(Color.primary.opacity(0.022))
    }

    private var languageBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(t("原文", "Source"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Menu {
                    Button(t("自动检测", "Auto Detect")) {
                        state.sourceLanguageIsAutomatic = true
                        onTranslateRequested()
                    }
                    Divider()
                    ForEach(SupportedLanguage.options, id: \.code) { option in
                        Button(localizedLanguage(option.code)) { onPickSourceLanguage(option.code) }
                    }
                } label: {
                    LanguageSelectorLabel(title: sourceLanguageTitle)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 150)

                Spacer(minLength: 4)
                compactIconButton(systemName: "speaker.wave.2", help: t("朗读原文", "Speak Source")) {
                    AudioSpeaker.shared.speak(state.sourceText, languageCode: state.sourceLanguageCode)
                }
                compactIconButton(systemName: "doc.on.doc", help: t("复制原文", "Copy Source"), action: onCopySource)
            }
            .frame(maxWidth: .infinity)

            Button(action: onSwapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 36, height: 32)
                    .neutralSurface(cornerRadius: 9, emphasized: true)
            }
            .buttonStyle(.plain)
            .disabled(state.sourceText.isEmpty || state.translatedText.isEmpty || state.isLoading)
            .help(t("互换语言和文本", "Swap Languages and Text"))

            HStack(spacing: 8) {
                Text(t("译文", "Translation"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Menu {
                    ForEach(SupportedLanguage.options, id: \.code) { option in
                        Button(localizedLanguage(option.code)) { onPickTargetLanguage(option.code) }
                    }
                } label: {
                    LanguageSelectorLabel(title: localizedLanguage(state.targetLanguageCode))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 150)

                Spacer(minLength: 4)
                compactIconButton(systemName: "speaker.wave.2", help: t("朗读译文", "Speak Translation")) {
                    AudioSpeaker.shared.speak(state.translatedText, languageCode: state.targetLanguageCode)
                }
                compactIconButton(systemName: "doc.on.doc", help: t("复制译文", "Copy Translation"), action: onCopyTranslated)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(Color.primary.opacity(0.025))
    }

    private var sourceLanguageTitle: String {
        localizedLanguage(state.sourceLanguageCode)
    }

    private var translationContent: some View {
        HStack(spacing: 0) {
            sourcePane
            Divider().opacity(0.62)
            resultPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(nsColor: .textBackgroundColor)
                .opacity(preferences.values.glassEffectEnabled ? 0.30 : 0.12)
        )
    }

    private var sourcePane: some View {
        VStack(alignment: .leading, spacing: 0) {
            SubmitTextEditor(
                text: $state.sourceText,
                font: .systemFont(ofSize: readingFontSize, weight: .regular),
                foregroundOpacity: 0.90,
                lineSpacing: readingLineSpacing,
                onSubmit: onTranslateRequested,
                onTextViewReady: onTextViewReady
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var resultPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = state.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else if state.isLoading && state.translatedText.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("翻译中…", "Translating…"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else if state.translatedText.isEmpty {
                Text(t("输入原文后按 Return 翻译", "Enter source text, then press Return"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                ReadOnlyTextView(
                    text: state.translatedText,
                    font: .systemFont(ofSize: readingFontSize, weight: .regular),
                    foregroundOpacity: 0.90,
                    lineSpacing: readingLineSpacing
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            providerMenu
            Spacer(minLength: 12)
            Button(action: onCopyTranslated) {
                HStack(spacing: 6) {
                    Text(t("复制翻译", "Copy Translation"))
                    HStack(spacing: 3) {
                        shortcutKey("⌘")
                        shortcutKey("↩︎")
                    }
                }
                .padding(.horizontal, 9)
                .frame(height: 28)
                .neutralSurface(cornerRadius: 8, emphasized: true)
            }
            .buttonStyle(.plain)
            .disabled(state.translatedText.isEmpty)

            Button(action: onClear) {
                HStack(spacing: 6) {
                    Text(t("重置", "Reset"))
                    HStack(spacing: 3) {
                        shortcutKey("⌘")
                        shortcutKey("⌫")
                    }
                }
                .padding(.horizontal, 9)
                .frame(height: 28)
                .neutralSurface(cornerRadius: 8)
            }
            .buttonStyle(.plain)
            .disabled(state.sourceText.isEmpty && state.translatedText.isEmpty)
            .help(t("清空原文和译文（Command-Delete）", "Clear source and translation (Command-Delete)"))
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(Color.primary.opacity(0.66))
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(Color.primary.opacity(0.035))
    }

    private var providerMenu: some View {
        Menu {
            ForEach(state.availableProviders) { provider in
                Button {
                    onSelectProvider(provider)
                } label: {
                    if provider == state.selectedProvider {
                        Label(provider.localizedDisplayName(language: language), systemImage: "checkmark")
                    } else {
                        Text(provider.localizedDisplayName(language: language))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: state.availableProviders.isEmpty ? "gearshape" : providerIcon(state.selectedProvider))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(providerMenuTitle)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .neutralSurface(cornerRadius: 8)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(state.availableProviders.isEmpty)
        .help(t("切换已配置的翻译服务", "Switch Configured Translation Service"))
    }

    private var providerMenuTitle: String {
        guard !state.availableProviders.isEmpty else {
            return t("未配置服务", "No Configured Service")
        }
        return state.selectedProvider.localizedDisplayName(language: language)
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

    private func compactIconButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func shortcutKey(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9.5, weight: .medium))
            .frame(minWidth: 17, minHeight: 17)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.6)
            )
    }

    private var language: InterfaceLanguage { preferences.values.interfaceLanguage }

    private func localizedLanguage(_ code: String) -> String {
        SupportedLanguage.localizedLabel(for: code, language: language)
    }

    private func t(_ chinese: String, _ english: String) -> String {
        PoptroText.value(chinese, english, language: language)
    }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}

final class FloatingTranslationPanel: NSPanel {
    let state = TranslationPanelState()
    var onTranslateRequested: (() -> Void)?
    var onSelectProvider: ((TranslationProvider) -> Void)?
    var onPickSourceLanguage: ((String) -> Void)?
    var onPickTargetLanguage: ((String) -> Void)?
    var onSwapLanguages: (() -> Void)?
    var onOpenGoogleAI: (() -> Void)?

    private weak var sourceTextView: NSTextView?
    private var hostingView: NSHostingView<TranslationPanelView>!
    private var isApplyingProgrammaticFrame = false

    private static let defaultSize = NSSize(width: 940, height: 580)
    private static let minPanelSize = NSSize(width: 740, height: 460)
    private static let maxPanelSize = NSSize(width: 1400, height: 1000)

    convenience init() {
        self.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        minSize = Self.minPanelSize
        maxSize = Self.maxPanelSize
        isMovableByWindowBackground = false

        let hosting = TransparentHostingView(rootView: TranslationPanelView(
            state: state,
            onTranslateRequested: { [weak self] in self?.onTranslateRequested?() },
            onClear: { [weak self] in self?.clearAll() },
            onSelectProvider: { [weak self] provider in self?.onSelectProvider?(provider) },
            onPickSourceLanguage: { [weak self] code in self?.onPickSourceLanguage?(code) },
            onPickTargetLanguage: { [weak self] code in self?.onPickTargetLanguage?(code) },
            onSwapLanguages: { [weak self] in self?.onSwapLanguages?() },
            onOpenGoogleAI: { [weak self] in self?.onOpenGoogleAI?() },
            onCopySource: { [weak self] in self?.copy(self?.state.sourceText) },
            onCopyTranslated: { [weak self] in self?.copy(self?.state.translatedText) },
            onTextViewReady: { [weak self] textView in self?.sourceTextView = textView }
        ))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.cornerRadius = 22
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        hostingView = hosting
        contentView = hosting

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMove), name: NSWindow.didMoveNotification, object: self
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResize), name: NSWindow.didResizeNotification, object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesChanged),
            name: .poptroPreferencesDidChange,
            object: nil
        )
    }

    func applyAppearance(mode: PanelAppearanceMode) {
        appearance = mode.nsAppearance
    }

    func focusInput() {
        // SwiftUI may report the NSTextView before AppKit has attached it to this
        // panel. macOS 27 rejects makeFirstResponder in that short window (and logs
        // that the view belongs to a different/nil window), so wait for the next
        // run-loop and retry briefly until the native view is actually mounted.
        NSApp.activate(ignoringOtherApps: true)
        focusInputWhenReady(remainingAttempts: 6)
    }

    private func focusInputWhenReady(remainingAttempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.contentView?.layoutSubtreeIfNeeded()

            if let textView = self.sourceTextView, textView.window === self {
                self.makeKeyAndOrderFront(nil)
                self.makeFirstResponder(textView)
                return
            }

            guard remainingAttempts > 1 else {
                self.makeKeyAndOrderFront(nil)
                return
            }
            self.focusInputWhenReady(remainingAttempts: remainingAttempts - 1)
        }
    }

    private func clearAll() {
        state.activeTranslationID = UUID()
        state.sourceText = ""
        state.translatedText = ""
        state.errorMessage = nil
        state.isLoading = false
        focusInput()
    }

    private func copy(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func handleMove() { persistPosition() }

    @objc private func handleResize() {
        guard !isApplyingProgrammaticFrame else { return }
        persistSize()
    }

    @objc private func handlePreferencesChanged() {
        applyAppearance(mode: AppPreferencesStore.shared.values.appearanceMode)
    }

    private func persistPosition() {
        var saved = PanelPosition.loadCurrent() ?? PanelPosition(
            x: frame.origin.x, y: frame.origin.y,
            width: frame.width, height: frame.height, wasManuallyResized: false
        )
        saved.x = frame.origin.x
        saved.y = frame.origin.y
        saved.save()
    }

    private func persistSize() {
        var saved = PanelPosition.loadCurrent() ?? PanelPosition(
            x: frame.origin.x, y: frame.origin.y,
            width: frame.width, height: frame.height, wasManuallyResized: true
        )
        saved.width = frame.width
        saved.height = frame.height
        saved.wasManuallyResized = true
        saved.save()
    }

    func show(near point: NSPoint) {
        present(using: PanelPosition.loadCurrent(), near: point)
    }

    func showCentered() {
        present(using: PanelPosition.loadCurrent(), near: nil)
    }

    private func present(using saved: PanelPosition?, near point: NSPoint?) {
        let size = sizeToUse(from: saved)
        var origin: NSPoint
        if let saved {
            origin = NSPoint(x: saved.x, y: saved.y)
        } else if let point {
            origin = NSPoint(x: point.x, y: point.y - size.height - 12)
        } else if let screen = NSScreen.main {
            origin = NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            )
        } else {
            origin = .zero
        }

        clampToVisibleScreen(&origin, size: size, near: point)
        isApplyingProgrammaticFrame = true
        setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        isApplyingProgrammaticFrame = false
        orderFrontRegardless()
        makeKey()
        observeResign()
    }

    private func sizeToUse(from saved: PanelPosition?) -> NSSize {
        guard let saved,
              saved.wasManuallyResized,
              saved.width >= Self.minPanelSize.width,
              saved.height >= Self.minPanelSize.height else {
            return Self.defaultSize
        }
        return NSSize(
            width: min(max(saved.width, Self.minPanelSize.width), Self.maxPanelSize.width),
            height: min(max(saved.height, Self.minPanelSize.height), Self.maxPanelSize.height)
        )
    }

    private func clampToVisibleScreen(_ origin: inout NSPoint, size: NSSize, near point: NSPoint?) {
        let referencePoint = point ?? origin
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(referencePoint) }) ?? NSScreen.main else {
            return
        }
        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
    }

    private func observeResign() {
        NotificationCenter.default.removeObserver(
            self, name: NSWindow.didResignKeyNotification, object: self
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResign), name: NSWindow.didResignKeyNotification, object: self
        )
    }

    @objc private func handleResign() {
        guard !state.isPinned else { return }
        close()
    }

    override func cancelOperation(_ sender: Any?) { close() }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if event.keyCode == 51, modifiers == [.command] {
            clearAll()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override var canBecomeKey: Bool { true }
}
