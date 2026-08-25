import AppKit
import SwiftUI

// AppKit-arcana: .nonactivatingPanel lets the panel take keystrokes without
// activating our app — so Esc/Enter returns you to whatever you were doing,
// exactly like Spotlight.
final class CapturePanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    // Borderless windows refuse key status unless we say so.
    override var canBecomeKey: Bool { true }
}

@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate {
    private lazy var panel: CapturePanel = {
        let panel = CapturePanel()
        panel.delegate = self
        return panel
    }()

    func toggle() {
        if panel.isVisible {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        // Fresh SwiftUI root each time: resets the field/space and re-fires focus.
        let view = CaptureView(
            onSave: { [weak self] title, space in
                Store.addTask(titled: title, in: space)
                self?.dismiss()
            },
            onCancel: { [weak self] in self?.dismiss() }
        )
        .modelContainer(Store.container)
        panel.contentView = NSHostingView(rootView: view)
        position(size: CaptureView.size(spaceCount: Store.spaceCount()))
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        panel.orderOut(nil)
    }

    private func position(size: CGSize) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }
        panel.setContentSize(size)
        let frame = screen.visibleFrame
        let x = frame.midX - size.width / 2
        let y = frame.minY + frame.height * 0.72 - size.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidResignKey(_ notification: Notification) {
        // Click anywhere else and the panel is gone, Spotlight-style.
        dismiss()
    }
}
