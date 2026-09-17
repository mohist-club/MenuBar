import AppKit
import KeyboardShortcuts
import SwiftUI

/// A small shortcut recorder that intentionally avoids KeyboardShortcuts.Recorder.
/// The package's recorder loads a localized SwiftPM resource bundle while SwiftUI
/// rebuilds the settings form. In manually assembled app bundles that lookup can
/// abort the whole process. The global-hotkey engine itself does not need that
/// resource bundle, so we keep it and provide a native capture button here.
struct ShortcutRecorderView: NSViewRepresentable {
    let name: KeyboardShortcuts.Name

    func makeNSView(context: Context) -> ShortcutCaptureButton {
        let button = ShortcutCaptureButton(title: "", target: context.coordinator, action: #selector(Coordinator.beginRecording(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.name = name
        button.refreshTitle()
        return button
    }

    func updateNSView(_ button: ShortcutCaptureButton, context: Context) {
        button.name = name
        if !button.isRecording {
            button.refreshTitle()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        @objc func beginRecording(_ sender: ShortcutCaptureButton) {
            sender.beginRecording()
        }
    }
}

final class ShortcutCaptureButton: NSButton {
    var name: KeyboardShortcuts.Name?
    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    func refreshTitle() {
        guard let name else {
            title = "点击设置"
            return
        }
        title = KeyboardShortcuts.getShortcut(for: name).map(String.init(describing:)) ?? "点击设置"
    }

    func beginRecording() {
        isRecording = true
        title = "请按快捷键…"
        window?.makeFirstResponder(self)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return super.performKeyEquivalent(with: event)
        }
        capture(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        capture(event)
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result, isRecording {
            isRecording = false
            refreshTitle()
        }
        return result
    }

    private func capture(_ event: NSEvent) {
        guard let name else { return }

        // Escape cancels. Delete/Backspace clears the currently assigned shortcut.
        if event.keyCode == 53 {
            finishRecording()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            KeyboardShortcuts.setShortcut(nil, for: name)
            finishRecording()
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function])
        let isFunctionKey = (122...126).contains(event.keyCode) || (96...111).contains(event.keyCode)
        guard !modifiers.isEmpty || isFunctionKey else {
            NSSound.beep()
            title = "请同时按修饰键"
            return
        }

        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else {
            NSSound.beep()
            return
        }

        // Always persist the user's choice. This deliberately does not reject a
        // shortcut merely because another app may also be using it.
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        finishRecording()
    }

    private func finishRecording() {
        isRecording = false
        refreshTitle()
        window?.makeFirstResponder(nil)
    }
}
