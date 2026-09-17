import AppKit
import SwiftUI
import Combine

final class TranslationPanelState: ObservableObject {
    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// 当前这次翻译实际用的目标语言代码(弹窗内可以手动改,覆盖设置里配置的主/备语言对)
    @Published var targetLanguageCode: String = "EN-US"
    /// 识别到的原文语言代码(用于"识别为 XX"徽标和朗读选择语音)
    @Published var sourceLanguageCode: String = "EN-US"
    @Published var providerDisplayName: String = "OpenAI"
    /// 锁定后窗口失去焦点(点了别处/切了别的 App)也不会自动关闭
    @Published var isPinned: Bool = false

    /// 手动输入模式下,面板打开时把光标焦点给输入框
    var isManualMode: Bool = false
}

/// 专门用来拖动窗口的透明背景层:SwiftUI 的 NSHostingView 会拦截空白区域的 mouseDown,
/// 导致系统自带的 isMovableByWindowBackground 在纯 SwiftUI 内容上基本不生效,
/// 所以手动实现一个"点击空白处拖动窗口"的图层,垫在所有内容最底下。
private final class DraggableBackgroundView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggableBackgroundView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// 卡片背景:macOS 26+ 用原生液态玻璃,旧系统回退成之前的纯色卡片背景
private struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 10
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content.background(RoundedRectangle(cornerRadius: cornerRadius).fill(Color(nsColor: .controlBackgroundColor)))
        }
    }
}

private extension View {
    func cardBackground() -> some View { modifier(CardBackground()) }
}

struct TranslationPanelView: View {
    @ObservedObject var state: TranslationPanelState
    var onTranslateRequested: () -> Void
    var onClear: () -> Void
    var onSwitchProvider: () -> Void
    var onPickTargetLanguage: (String) -> Void
    var onCopySource: () -> Void
    var onCopyTranslated: () -> Void
    var onTextViewReady: (NSTextView) -> Void

    @State private var resultExpanded = true


    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer {
                    panelContent
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                panelContent
                    .background(VisualEffectBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var panelContent: some View {
        ZStack {
            WindowDragHandle()

            VStack(alignment: .leading, spacing: 10) {
                topBar
                sourceCard
                resultCard
                Text("⌘ + Return 复制翻译结果")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
        .frame(minWidth: 340, maxWidth: .infinity, alignment: .topLeading)
        // Cmd+Return:复制译文(不可见的按钮,只用来挂系统级快捷键)
        .background(
            Button("") { onCopyTranslated() }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
        )
    }

    // MARK: 顶部工具栏

    private var topBar: some View {
        HStack {
            // 锁定按钮:锁定后窗口失焦也不会自动关闭,点击这里(左上角)切换锁定状态
            Button(action: { state.isPinned.toggle() }) {
                Image(systemName: state.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(state.isPinned ? Color.accentColor : .secondary)
            }
            .help(state.isPinned ? "已锁定,点击取消锁定" : "锁定窗口(失焦不自动关闭)")

            Spacer()
            Button(action: onClear) {
                Image(systemName: "eraser")
            }
            .help("清除")
            Button(action: onSwitchProvider) {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .help("切换翻译引擎")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.system(size: 13))
    }

    // MARK: 原文卡片

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SubmitTextEditor(
                text: $state.sourceText,
                onSubmit: onTranslateRequested,
                onTextViewReady: onTextViewReady
            )
            .frame(minHeight: 44, idealHeight: 60, maxHeight: 160)

            HStack(spacing: 12) {
                Button(action: { AudioSpeaker.shared.speak(state.sourceText, languageCode: state.sourceLanguageCode) }) {
                    Image(systemName: "speaker.wave.2")
                }
                Button(action: onCopySource) {
                    Image(systemName: "doc.on.doc")
                }
                if !state.sourceText.isEmpty {
                    Text("识别为 ")
                        .foregroundColor(.secondary)
                    + Text(SupportedLanguage.label(for: state.sourceLanguageCode))
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .cardBackground()
    }

    // MARK: 译文卡片

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "character.bubble.fill")
                    .foregroundStyle(Color.accentColor)

                // 目标语言选择菜单:不再局限于设置里配的主/备两种,这里能选任意语言,
                // 选中即用新语言重新翻译一次
                Menu {
                    ForEach(SupportedLanguage.options, id: \.code) { option in
                        Button(option.label) { onPickTargetLanguage(option.code) }
                    }
                } label: {
                    Text(SupportedLanguage.label(for: state.targetLanguageCode))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()
                Text(state.providerDisplayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { resultExpanded.toggle() } }) {
                    Image(systemName: resultExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium))

            if resultExpanded {
                ScrollView {
                    Group {
                        if let error = state.errorMessage {
                            Text(error).foregroundStyle(.red)
                        } else if state.isLoading && state.translatedText.isEmpty {
                            Text("翻译中…").foregroundStyle(.secondary)
                        } else if state.translatedText.isEmpty {
                            Text("按 Enter 翻译,Shift+Enter 换行")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(state.translatedText)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 40, maxHeight: 240)

                if !state.translatedText.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: {
                            AudioSpeaker.shared.speak(state.translatedText, languageCode: state.targetLanguageCode)
                        }) {
                            Image(systemName: "speaker.wave.2")
                        }
                        Button(action: onCopyTranslated) {
                            Image(systemName: "doc.on.doc")
                        }
                        Spacer()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .cardBackground()
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// 不抢焦点(但可以接收键盘输入)、悬浮在最上层的翻译结果窗口
final class FloatingTranslationPanel: NSPanel {
    let state = TranslationPanelState()
    var onTranslateRequested: (() -> Void)?
    var onSwitchProvider: (() -> Void)?
    var onPickTargetLanguage: ((String) -> Void)?

    private weak var sourceTextView: NSTextView?
    private var hostingView: NSHostingView<TranslationPanelView>!
    private var cancellables = Set<AnyCancellable>()

    /// 用户是否已经手动拖动过边缘调整过大小——一旦手动调过,后续内容变化就不再自动改高度了,
    /// 避免"自动适应高度"和"用户手动调整大小"互相打架
    private var userResizedManually = false
    /// 标记接下来这次 frame 变化是代码自己触发的(自动适应高度/记忆位置),
    /// 用来和用户真正拖拽窗口边缘区分开
    private var isApplyingProgrammaticFrame = false

    private static let defaultSize = NSSize(width: 400, height: 340)
    private static let minPanelSize = NSSize(width: 340, height: 220)
    private static let maxPanelSize = NSSize(width: 720, height: 780)

    convenience init() {
        self.init(
            contentRect: NSRect(origin: .zero, size: FloatingTranslationPanel.defaultSize),
            // .resizable 让用户可以原生拖边缘/角落调整宽高,borderless 依然没有标题栏
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
        isMovableByWindowBackground = true // 留着作为兜底,主要拖动逻辑走 WindowDragHandle

        let hosting = NSHostingView(rootView: TranslationPanelView(
            state: state,
            onTranslateRequested: { [weak self] in self?.onTranslateRequested?() },
            onClear: { [weak self] in self?.clearAll() },
            onSwitchProvider: { [weak self] in self?.onSwitchProvider?() },
            onPickTargetLanguage: { [weak self] code in self?.onPickTargetLanguage?(code) },
            onCopySource: { [weak self] in self?.copy(self?.state.sourceText) },
            onCopyTranslated: { [weak self] in self?.copy(self?.state.translatedText) },
            onTextViewReady: { [weak self] textView in self?.sourceTextView = textView }
        ))
        self.hostingView = hosting
        contentView = hosting

        observeContentChangesForAutoResize()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMove), name: NSWindow.didMoveNotification, object: self
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResize), name: NSWindow.didResizeNotification, object: self
        )
    }

    /// 浅色/深色/跟随系统。界面里所有颜色都用的是 .primary/.secondary/.controlBackgroundColor
    /// 这类语义色,只要在这一层设置 appearance,底下所有颜色会自动跟着变。
    func applyAppearance(mode: PanelAppearanceMode) {
        switch mode {
        case .light: appearance = NSAppearance(named: .aqua)
        case .dark: appearance = NSAppearance(named: .darkAqua)
        case .system: appearance = nil
        }
    }

    private func clearAll() {
        state.sourceText = ""
        state.translatedText = ""
        state.errorMessage = nil
    }

    private func copy(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// 让输入框获得键盘焦点(手动输入模式下呼出面板后直接就能打字)
    func focusInput() {
        guard let textView = sourceTextView else { return }
        makeFirstResponder(textView)
    }

    // MARK: - 内容自适应高度(只在用户没有手动调整过大小时生效)

    private func observeContentChangesForAutoResize() {
        state.$sourceText
            .combineLatest(state.$translatedText, state.$errorMessage)
            .sink { [weak self] _, _, _ in
                DispatchQueue.main.async { self?.fitContentHeight() }
            }
            .store(in: &cancellables)
    }

    private func fitContentHeight() {
        guard !userResizedManually else { return }

        let fittingHeight = hostingView.fittingSize.height
        guard fittingHeight > 0 else { return }

        let clampedHeight = min(max(fittingHeight, Self.minPanelSize.height), Self.maxPanelSize.height)
        let current = frame
        guard abs(current.height - clampedHeight) > 1 else { return }

        let newOrigin = NSPoint(x: current.origin.x, y: current.maxY - clampedHeight)
        let newFrame = NSRect(origin: newOrigin, size: NSSize(width: current.width, height: clampedHeight))
        applyProgrammaticFrame(newFrame, animate: true)
    }

    private func applyProgrammaticFrame(_ newFrame: NSRect, animate: Bool) {
        isApplyingProgrammaticFrame = true
        setFrame(newFrame, display: true, animate: animate)
        isApplyingProgrammaticFrame = false
    }

    @objc private func handleResize() {
        // 只有不是代码自己发起的 resize,才算"用户手动拖了边缘",之后停止自动适应高度,
        // 并且把这次手动定的大小记下来,下次呼出窗口沿用
        if !isApplyingProgrammaticFrame {
            userResizedManually = true
            persistManualSize()
        }
    }

    // MARK: - 位置记忆

    @objc private func handleMove() {
        persistPosition()
    }

    private func persistPosition() {
        var saved = PanelPosition.loadCurrent() ?? PanelPosition(
            x: frame.origin.x, y: frame.origin.y,
            width: frame.size.width, height: frame.size.height, wasManuallyResized: false
        )
        saved.x = frame.origin.x
        saved.y = frame.origin.y
        saved.save()
    }

    private func persistManualSize() {
        var saved = PanelPosition.loadCurrent() ?? PanelPosition(
            x: frame.origin.x, y: frame.origin.y,
            width: frame.size.width, height: frame.size.height, wasManuallyResized: true
        )
        saved.width = frame.size.width
        saved.height = frame.size.height
        saved.wasManuallyResized = true
        saved.save()
    }

    /// 在指定屏幕坐标附近弹出;如果之前拖动过窗口,优先用上次的位置;
    /// 如果之前手动调整过大小,也沿用上次的宽高
    func show(near point: NSPoint) {
        let saved = PanelPosition.loadCurrent()
        let size = sizeToUse(from: saved)
        var origin: NSPoint
        if let saved {
            origin = NSPoint(x: saved.x, y: saved.y)
        } else {
            origin = NSPoint(x: point.x, y: point.y - size.height - 12)
        }
        clampToVisibleScreen(&origin, size: size, near: point)

        applyProgrammaticFrame(NSRect(origin: origin, size: size), animate: false)
        if saved?.wasManuallyResized == true { userResizedManually = true }
        orderFrontRegardless()
        makeKey()
        observeResign()
    }

    /// 手动输入模式:优先用上次拖动的位置;没有的话屏幕居中弹出
    func showCentered() {
        let saved = PanelPosition.loadCurrent()
        let size = sizeToUse(from: saved)
        var origin: NSPoint
        if let saved {
            origin = NSPoint(x: saved.x, y: saved.y)
        } else if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        } else {
            origin = .zero
        }
        clampToVisibleScreen(&origin, size: size, near: nil)

        applyProgrammaticFrame(NSRect(origin: origin, size: size), animate: false)
        if saved?.wasManuallyResized == true { userResizedManually = true }
        orderFrontRegardless()
        makeKey()
        observeResign()
    }

    /// 只有用户真的手动拖过边缘调整过大小,才沿用记住的宽高;否则用默认尺寸,
    /// 交给"内容自适应高度"逻辑接管
    private func sizeToUse(from saved: PanelPosition?) -> NSSize {
        guard let saved, saved.wasManuallyResized else { return Self.defaultSize }
        return NSSize(width: saved.width, height: saved.height)
    }

    /// 避免窗口(尤其是记住的旧位置,可能来自分辨率不同的外接屏)超出当前屏幕可见范围
    private func clampToVisibleScreen(_ origin: inout NSPoint, size: NSSize, near point: NSPoint?) {
        let referencePoint = point ?? origin
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(referencePoint) }) ?? NSScreen.main
        else { return }
        let visible = screen.visibleFrame
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
    }

    private func observeResign() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResign), name: NSWindow.didResignKeyNotification, object: self
        )
    }

    @objc private func handleResign() {
        guard !state.isPinned else { return }
        close()
    }

    override func cancelOperation(_ sender: Any?) {
        close() // Esc 关闭
    }

    override var canBecomeKey: Bool { true }
}
