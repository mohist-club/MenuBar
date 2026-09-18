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
}
