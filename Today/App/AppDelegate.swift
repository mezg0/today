import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    private let panel = CapturePanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey = HotKey(keyCode: HotKeyConfig.keyCode, modifiers: HotKeyConfig.modifiers) { [weak self] in
            self?.panel.toggle()
        }
        if hotKey == nil {
            NSLog("Failed to register global hotkey — is another app holding \u{2325}Space?")
        }
        // Dev aid: `TODAY_SHOW_CAPTURE=1 Today.app/Contents/MacOS/Today` pops the panel on launch.
        if ProcessInfo.processInfo.environment["TODAY_SHOW_CAPTURE"] == "1" {
            panel.show()
        }
    }

    func showPanel() {
        panel.show()
    }
}
