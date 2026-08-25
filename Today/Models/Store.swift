import Foundation
import SwiftData

@MainActor
enum Store {
    static let container: ModelContainer = {
        let schema = Schema([Task.self, Space.self])
        let dir = URL.applicationSupportDirectory.appending(path: "Today", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "Today.store")

        let container: ModelContainer
        do {
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // No iCloud entitlement/team (e.g. unsigned dev build) — same store, sync off.
            NSLog("CloudKit unavailable, running local-only: \(error)")
            do {
                let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                // Corrupt or unwritable store: stay usable for the session rather than die at launch.
                NSLog("Local store unavailable, running in memory: \(error)")
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try! ModelContainer(for: schema, configurations: [config])
            }
        }
        container.mainContext.undoManager = UndoManager()
        return container
    }()
}
