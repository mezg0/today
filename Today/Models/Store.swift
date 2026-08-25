import Foundation
import SwiftData

@MainActor
enum Store {
    static let container: ModelContainer = {
        let schema = Schema([Task.self, Space.self])
        let dir = URL.applicationSupportDirectory.appending(path: "Today", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "Today.store")
        do {
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // No iCloud entitlement/team (e.g. unsigned dev build) — same store, sync off.
            NSLog("CloudKit unavailable, running local-only: \(error)")
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not open the local store: \(error)")
            }
        }
    }()

    static var context: ModelContext { container.mainContext }

    static func addTask(titled title: String, in space: Space?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(Task(title: trimmed, space: space))
        try? context.save()
    }

    static func spaceCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<Space>())) ?? 0
    }
}
