import AppKit
import ApplicationServices

final class TextCaptureService {
    static let shared = TextCaptureService()
    private init() {}

    /// 当前鼠标位置(用于悬浮窗定位)
    func currentMouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }

    /// 获取当前选中的文本。异步返回,因为剪贴板方案需要短暂延时等待系统完成拷贝。
    func captureSelectedText(completion: @escaping (String?) -> Void) {
        if let text = captureViaAccessibility(), !text.isEmpty {
            completion(text)
            return
        }
        captureViaSimulatedCopy(completion: completion)
    }

    // MARK: - 方案 A: Accessibility API

    private func captureViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement
        )
        guard focusedResult == .success, let element = focusedElement else { return nil }
        // swiftlint:disable:next force_cast
        let axElement = element as! AXUIElement

        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            axElement, kAXSelectedTextAttribute as CFString, &selectedText
        )
        guard textResult == .success, let text = selectedText as? String else { return nil }
        return text
    }

    // MARK: - 方案 B: 模拟 Cmd+C(兜底),用完恢复剪贴板

    private func captureViaSimulatedCopy(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        // 备份触发前的剪贴板全部内容,稍后恢复,避免污染用户剪贴板
        let backupItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []

        simulateCmdC()

        // 给系统一点时间完成拷贝操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            let changed = pasteboard.changeCount != previousChangeCount
            let text = changed ? pasteboard.string(forType: .string) : nil

            // 恢复原剪贴板内容
            pasteboard.clearContents()
            if !backupItems.isEmpty {
                pasteboard.writeObjects(backupItems)
            }

            completion(text)
        }
    }

    private func simulateCmdC() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // kVK_ANSI_C
        cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand

        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
    }
}
