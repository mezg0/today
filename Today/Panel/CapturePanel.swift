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
        // Window-server shadow: shaped from the content's alpha, drawn outside
        // the frame, never hit-tested. Must be invalidated whenever content changes size.
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
    // Space the field + tabs take above the list, and clearance to keep off the Dock.
    private static let chromeHeight: CGFloat = 110
    private static let dockMargin: CGFloat = 24
    private static let topAnchor: CGFloat = 0.88

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
        topY = frame.minY + frame.height * Self.topAnchor
        centerX = frame.midX
        let maxListHeight = (topY - frame.minY) - Self.chromeHeight - Self.dockMargin

        // Fresh SwiftUI root each time: resets the field and re-fires focus.
        let view = PanelView(
            maxListHeight: maxListHeight,
            onDismiss: { [weak self] in self?.dismiss() },
            onSizeChange: { [weak self] size in self?.resize(to: size) }
        )
        .modelContainer(Store.container)
        let hosting = NSHostingView(rootView: view)
        // Belt and braces with PanelView's clipShape: the glass backdrop is a
        // layer sized to the hosting view, so mask that layer to the same shape.
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = PanelView.cornerRadius
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        resize(to: hosting.fittingSize)

        panel.makeKeyAndOrderFront(nil)
        // The first shadow is computed before the glass has drawn; redo it after.
        DispatchQueue.main.async { [weak self] in self?.panel.invalidateShadow() }
    }

    func dismiss() {
        // ⌥Space mid-edit must not lose the last keystrokes.
        try? Store.container.mainContext.save()
        panel.orderOut(nil)
        // Tear the view down so nothing (focus re-homing, timers) keeps running offscreen.
        panel.contentView = NSView()
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
        panel.invalidateShadow()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Click anywhere else and the panel is gone, Spotlight-style. Deferred so a
        // context menu that briefly borrows key status doesn't tear the panel down.
        DispatchQueue.main.async { [weak self] in
            guard let self, panel.isVisible, !panel.isKeyWindow else { return }
            dismiss()
        }
    }
}
