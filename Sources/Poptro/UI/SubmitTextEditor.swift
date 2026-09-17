import AppKit
import SwiftUI

/// 输入框交互:普通回车 = 提交翻译,Shift+回车 = 换行
struct SubmitTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 15)
    var onSubmit: () -> Void
    /// 把内部真正的 NSTextView 暴露出去,方便外部手动设置第一响应者(让输入框自动获得焦点)
    var onTextViewReady: (NSTextView) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = font
        // 用语义色(labelColor)而不是写死白色,这样强制深色/跟随系统两种模式下文字颜色都自动正确
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.string = text
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.insertionPointColor = .labelColor

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        // 内容超出高度时显示系统标准滚动条,而不是把窗口硬撑大
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView
        onTextViewReady(textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
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
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }

            let shiftPressed = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            if shiftPressed {
                return false // 交给系统默认处理,插入换行
            }
            parent.onSubmit()
            return true // 拦截掉,不换行
        }
    }
}
