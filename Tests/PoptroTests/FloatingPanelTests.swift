import AppKit
import XCTest
@testable import Poptro

@MainActor
final class FloatingPanelTests: XCTestCase {
    func testTranslationPanelCanRenderWithoutSwiftPMAppResourceBundle() {
        _ = NSApplication.shared
        let panel = FloatingTranslationPanel()

        panel.contentView?.layoutSubtreeIfNeeded()

        XCTAssertNotNil(panel.contentView)
        XCTAssertEqual(panel.state.sourceText, "")
        panel.close()
    }

    func testTranslationPanelForcesOverlayScrollers() {
        _ = NSApplication.shared
        let panel = FloatingTranslationPanel()
        panel.state.sourceText = "The purpose of this business trip is to organize two seminars in Northern Thailand."
        panel.state.translatedText = "此次商务出差的目的是在泰国北部举办两场研讨会。"
        panel.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        panel.contentView?.layoutSubtreeIfNeeded()

        let textScrollViews = descendants(of: panel.contentView)
            .compactMap { $0 as? NSScrollView }
            .filter { $0.documentView is NSTextView }

        XCTAssertGreaterThanOrEqual(textScrollViews.count, 2)
        for (index, scrollView) in textScrollViews.enumerated() {
            XCTAssertEqual(
                scrollView.scrollerStyle,
                .overlay,
                "Text scroll view \(index) must not inherit the system's legacy scrollbar style"
            )
        }
        XCTAssertTrue(textScrollViews.allSatisfy { $0.autohidesScrollers })
        XCTAssertTrue(textScrollViews.allSatisfy {
            (($0.documentView as? NSTextView)?.font?.pointSize ?? 0) == 16
        })

        if let capturePath = ProcessInfo.processInfo.environment["POPTRO_UI_CAPTURE"],
           let contentView = panel.contentView,
           let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) {
            contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
            try? bitmap.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: capturePath))
        }
        panel.close()
    }

    func testTranslationTextColorsFollowPanelAppearance() {
        _ = NSApplication.shared
        let panel = FloatingTranslationPanel()
        panel.state.sourceText = "Dark mode source"
        panel.state.translatedText = "暗黑模式译文"

        panel.applyAppearance(mode: .dark)
        settle(panel)
        let darkLuminances = textViews(in: panel).compactMap(relativeLuminance)
        XCTAssertGreaterThanOrEqual(darkLuminances.count, 2)
        XCTAssertTrue(darkLuminances.allSatisfy { $0 > 0.70 })

        panel.applyAppearance(mode: .light)
        settle(panel)
        let lightLuminances = textViews(in: panel).compactMap(relativeLuminance)
        XCTAssertGreaterThanOrEqual(lightLuminances.count, 2)
        XCTAssertTrue(lightLuminances.allSatisfy { $0 < 0.30 })
        panel.close()
    }

    private func settle(_ panel: FloatingTranslationPanel) {
        panel.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        panel.contentView?.layoutSubtreeIfNeeded()
    }

    private func textViews(in panel: FloatingTranslationPanel) -> [NSTextView] {
        descendants(of: panel.contentView)
            .compactMap { ($0 as? NSScrollView)?.documentView as? NSTextView }
    }

    private func relativeLuminance(_ textView: NSTextView) -> CGFloat? {
        var luminance: CGFloat?
        textView.effectiveAppearance.performAsCurrentDrawingAppearance {
            guard let color = textView.textColor?.usingColorSpace(.deviceRGB) else { return }
            luminance = (0.2126 * color.redComponent)
                + (0.7152 * color.greenComponent)
                + (0.0722 * color.blueComponent)
        }
        return luminance
    }

    private func descendants(of view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return [view] + view.subviews.flatMap { descendants(of: $0) }
    }
}
