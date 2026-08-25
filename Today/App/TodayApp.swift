import SwiftUI
import SwiftData

@main
struct TodayApp: App {
    // AppKit-arcana: the delegate owns everything SwiftUI can't do —
    // the global hotkey and the floating capture panel.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Today", systemImage: "checkmark.circle.fill") {
            TodayListView()
                .modelContainer(Store.container)
        }
        .menuBarExtraStyle(.window)
    }
}
