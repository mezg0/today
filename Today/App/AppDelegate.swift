import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    private let capture = CapturePanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey = HotKey(keyCode: HotKeyConfig.keyCode, modifiers: HotKeyConfig.modifiers) { [weak self] in
            self?.capture.toggle()
        }
        if hotKey == nil {
            NSLog("Failed to register global hotkey — is another app holding \u{2325}Space?")
        }
        // Dev aid: `TODAY_SHOW_CAPTURE=1 open Today.app` pops the panel without the hotkey.
        if ProcessInfo.processInfo.environment["TODAY_SHOW_CAPTURE"] != nil {
            capture.show()
        }
    }
}
