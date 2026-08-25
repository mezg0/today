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
    var space: Space?

    init(title: String, space: Space? = nil) {
        self.title = title
        self.space = space
    }

    var isDone: Bool { completedAt != nil }
}
