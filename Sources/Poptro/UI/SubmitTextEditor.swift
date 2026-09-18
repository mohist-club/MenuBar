import AppKit
import SwiftUI

/// macOS 会在视图挂载后按“显示滚动条”系统偏好重设样式。
/// 在属性入口处固定 overlay，避免“始终显示”产生传统白色轨道。
private final class OverlayTextScrollView: NSScrollView {
    override var scrollerStyle: NSScroller.Style {
        get { .overlay }
        set { super.scrollerStyle = .overlay }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        super.scrollerStyle = .overlay
        autohidesScrollers = true
    }
}

/// 输入框交互:普通回车 = 提交翻译,Shift+回车 = 换行
struct SubmitTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 15)
    var textColor: NSColor = .labelColor.withAlphaComponent(0.90)
    var lineSpacing: CGFloat = 4
    var onSubmit: () -> Void
    /// 把内部真正的 NSTextView 暴露出去,方便外部手动设置第一响应者(让输入框自动获得焦点)
    var onTextViewReady: (NSTextView) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.string = text
        applyTypography(to: textView)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.insertionPointColor = textColor

        let scrollView = OverlayTextScrollView()
        scrollView.documentView = textView
        // 强制使用悬浮式滚动条，避免用户把系统滚动条设为“始终显示”时出现宽白轨道。
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerKnobStyle = .default
        scrollView.verticalScroller?.controlSize = .mini
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView
        onTextViewReady(textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        applyTypography(to: textView)
    }

    private func applyTypography(to textView: NSTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textView.font = font
        textView.textColor = textColor
        textView.defaultParagraphStyle = paragraphStyle
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        textView.textStorage?.addAttributes([
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ], range: fullRange)
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SubmitTextEditor
        weak var textView: NSTextView?
        init(_ parent: SubmitTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let commandName = NSStringFromSelector(commandSelector)
            let returnCommands = [
                "insertNewline:",
                "insertNewlineIgnoringFieldEditor:",
                "insertParagraphSeparator:"
            ]
            guard returnCommands.contains(commandName) else { return false }

            let shiftPressed = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            if shiftPressed {
                return false // 交给系统默认处理,插入换行
            }
            parent.onSubmit()
            return true // 拦截掉,不换行
        }
    }
}

/// 与输入栏共享排版和 overlay 滚动行为的只读译文视图。
struct ReadOnlyTextView: NSViewRepresentable {
    let text: String
    var font: NSFont = .systemFont(ofSize: 16)
    var textColor: NSColor = .labelColor.withAlphaComponent(0.90)
    var lineSpacing: CGFloat = 4

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = .zero
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        applyTypography(to: textView)

        let scrollView = OverlayTextScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerKnobStyle = .default
        scrollView.verticalScroller?.controlSize = .mini
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        applyTypography(to: textView)
    }

    private func applyTypography(to textView: NSTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textView.font = font
        textView.textColor = textColor
        textView.defaultParagraphStyle = paragraphStyle
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        textView.textStorage?.addAttributes([
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ], range: fullRange)
    }
}
