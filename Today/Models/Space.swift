import Foundation
import SwiftData

@Model
final class Space {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    // Deleting a space leaves its tasks in place, just unspaced.
    @Relationship(deleteRule: .nullify, inverse: \Task.space)
    var tasks: [Task]?

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}
