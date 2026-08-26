import Foundation
import SwiftData

// CloudKit rule: every stored property must be optional or have a default,
// relationships must be optional, and no unique constraints — hence the shape.
@Model
final class Task {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date.now
    var completedAt: Date?
    var snoozedUntil: Date?
    var notes: String?
    // Manual order within a space; lower is higher. New tasks go to the top.
    var sortOrder: Double = 0
    var space: Space?

    init(title: String, space: Space? = nil) {
        self.title = title
        self.space = space
    }

    var isDone: Bool { completedAt != nil }
}
