import SwiftUI

@main
struct TodayApp: App {
    // AppKit-arcana: the delegate owns everything SwiftUI can't do —
    // the global hotkey and the floating panel that is the whole UI.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Today", systemImage: "checkmark.circle.fill") {
            Button("Open Today   \u{2325}Space") { appDelegate.showPanel() }
            Divider()
            Button("Quit Today") { NSApp.terminate(nil) }
        }
    }
}
