import AppKit
import SwiftUI

// AppKit-arcana: .nonactivatingPanel lets the panel take keystrokes without
// activating our app — so Esc returns you to whatever you were doing,
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

    // Esc fallback for when nothing inside has focus.
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

@MainActor
final class CapturePanelController: NSObject, NSWindowDelegate {
    private lazy var panel: CapturePanel = {
        let panel = CapturePanel()
        panel.delegate = self
        return panel
    }()

    // The panel grows/shrinks with the list; keep its top edge pinned here.
    private var topY: CGFloat = 0
    private var centerX: CGFloat = 0

    func toggle() {
        if panel.isVisible {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        topY = frame.minY + frame.height * 0.88
        centerX = frame.midX
        // Field + tabs + footer are ~150pt; leave a margin above the Dock.
        let maxListHeight = topY - frame.minY - 150 - 24

        // Fresh SwiftUI root each time: resets the field and re-fires focus.
        let view = PanelView(
            maxListHeight: maxListHeight,
            onDismiss: { [weak self] in self?.dismiss() },
            onSizeChange: { [weak self] size in self?.resize(to: size) }
        )
        .modelContainer(Store.container)
        let hosting = NSHostingView(rootView: view)
        // The glass backdrop is a layer that fills the hosting view, not the
        // SwiftUI shape — mask the layer itself so the corners stay rounded.
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = PanelView.cornerRadius
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        resize(to: hosting.fittingSize)

        // A hair of fade reads as "instant" but hides the first-frame pop.
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.makeKeyAndOrderFront(nil)
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.08
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    func dismiss() {
        panel.orderOut(nil)
    }

    private func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let frame = NSRect(
            x: centerX - size.width / 2,
            y: topY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
        // The window shadow is cached from the opaque region; refresh it or it lags the new size.
        panel.invalidateShadow()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Click anywhere else and the panel is gone, Spotlight-style.
        dismiss()
    }
}
