import SwiftUI
import SwiftData

struct TodayListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Task.createdAt, order: .reverse) private var tasks: [Task]
    @Query(sort: \Space.sortOrder) private var spaces: [Space]
    @AppStorage("selectedSpaceID") private var selectedSpaceID = ""

    @State private var selectedID: UUID?
    // Tasks that were just completed: they keep their spot in the list for a
    // beat so the checkmark can land before the row settles down to Done.
    @State private var settling: Set<UUID> = []

    @State private var isEditingSpace = false
    @State private var editingSpace: Space?
    @State private var spaceName = ""

    private enum Focus { case list, spaceEditor }
    @FocusState private var focus: Focus?

    private var selectedSpace: Space? {
        spaces.first { $0.id.uuidString == selectedSpaceID }
    }

    private func inScope(_ task: Task) -> Bool {
        guard let selectedSpace else { return true }
        return task.space?.id == selectedSpace.id
    }

    private var active: [Task] {
        let scoped = tasks.filter { task in
            guard inScope(task) else { return false }
            if task.completedAt != nil { return settling.contains(task.id) }
            if let snooze = task.snoozedUntil, snooze > .now { return false }
            return true
        }
        guard selectedSpace == nil else { return scoped }
        // All view: inbox first, then spaces in their order; newest first within.
        let order = Dictionary(uniqueKeysWithValues: spaces.enumerated().map { ($1.id, $0 + 1) })
        return scoped.sorted { a, b in
            let oa = a.space.flatMap { order[$0.id] } ?? 0
            let ob = b.space.flatMap { order[$0.id] } ?? 0
            return oa != ob ? oa < ob : a.createdAt > b.createdAt
        }
    }

    private var done: [Task] {
        tasks.filter { task in
            guard inScope(task) else { return false }
            guard let completed = task.completedAt, !settling.contains(task.id) else { return false }
            return Calendar.current.isDateInToday(completed)
        }
    }

    private var visible: [Task] { active + done }

    private enum Row: Identifiable {
        case header(id: String, title: String)
        case task(Task)

        var id: String {
            switch self {
            case .header(let id, _): id
            case .task(let task): task.id.uuidString
            }
        }
    }

    private var rows: [Row] {
        var rows: [Row] = []
        if selectedSpace == nil {
            var lastGroup: UUID?? = .none
            for task in active {
                let group: UUID? = task.space?.id
                if lastGroup != .some(group) {
                    rows.append(.header(id: "space-\(group?.uuidString ?? "inbox")", title: task.space?.name ?? "Inbox"))
                    lastGroup = .some(group)
                }
                rows.append(.task(task))
            }
        } else {
            rows += active.map(Row.task)
        }
        if !done.isEmpty {
            rows.append(.header(id: "done", title: "Done"))
            rows += done.map(Row.task)
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            spaceBar
            if visible.isEmpty {
                emptyState
            } else {
                list
            }
            footer
        }
        .frame(width: 340)
        .focusable()
        .focusEffectDisabled()
        .focused($focus, equals: .list)
        .onKeyPress(action: handleKey)
        .onAppear { focus = .list }
    }

    // MARK: - Header & spaces

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selectedSpace?.name ?? "All")
                .font(.system(size: 15, weight: .semibold))
                .contentTransition(.numericText())
            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .animation(.snappy(duration: 0.2), value: selectedSpaceID)
    }

    private var spaceBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                SpacePill(label: "All", key: "1", isSelected: selectedSpace == nil) {
                    selectedSpaceID = ""
                }
                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    SpacePill(
                        label: space.name,
                        key: index < 8 ? "\(index + 2)" : nil,
                        isSelected: selectedSpace?.id == space.id
                    ) {
                        selectedSpaceID = space.id.uuidString
                    }
                    .contextMenu {
                        Button("Rename") { beginEditing(space) }
                        Button("Delete Space", role: .destructive) { delete(space) }
                    }
                }
                if isEditingSpace {
                    TextField("Space name", text: $spaceName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 90)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                        .focused($focus, equals: .spaceEditor)
                        .onSubmit(commitSpaceEdit)
                        .onExitCommand(perform: cancelSpaceEdit)
                } else {
                    SpacePill(label: "+", key: nil, isSelected: false) { beginEditing(nil) }
                        .help("New space")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func beginEditing(_ space: Space?) {
        editingSpace = space
        spaceName = space?.name ?? ""
        isEditingSpace = true
        DispatchQueue.main.async { focus = .spaceEditor }
    }

    private func commitSpaceEdit() {
        let name = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { cancelSpaceEdit() }
        guard !name.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            if let editingSpace {
                editingSpace.name = name
            } else {
                let space = Space(name: name, sortOrder: (spaces.last?.sortOrder ?? -1) + 1)
                context.insert(space)
                selectedSpaceID = space.id.uuidString
            }
        }
        try? context.save()
    }

    private func cancelSpaceEdit() {
        isEditingSpace = false
        editingSpace = nil
        spaceName = ""
        focus = .list
    }

    private func delete(_ space: Space) {
        if selectedSpace?.id == space.id { selectedSpaceID = "" }
        withAnimation(.snappy(duration: 0.2)) {
            context.delete(space)
        }
        try? context.save()
    }

    private func selectSpace(at index: Int?) {
        withAnimation(.snappy(duration: 0.2)) {
            if let index, spaces.indices.contains(index) {
                selectedSpaceID = spaces[index].id.uuidString
            } else {
                selectedSpaceID = ""
            }
        }
        selectedID = nil
    }

    private func cycleSpace(by delta: Int) {
        guard !spaces.isEmpty else { return }
        // Position 0 is All, then spaces in order.
        let current = spaces.firstIndex { $0.id == selectedSpace?.id }.map { $0 + 1 } ?? 0
        let count = spaces.count + 1
        let next = (current + delta + count) % count
        selectSpace(at: next == 0 ? nil : next - 1)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(rows) { row in
                    switch row {
                    case .header(_, let title):
                        sectionHeader(title)
                    case .task(let task):
                        TaskRow(
                            title: task.title,
                            isDone: task.isDone,
                            isSelected: task.id == selectedID
                        ) {
                            selectedID = task.id
                            toggle(task)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(maxHeight: 440)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("All clear")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var footer: some View {
        HStack {
            Text("\u{2325}Space capture \u{00B7} 1\u{2013}9 tabs \u{00B7} \u{21E5} cycle")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3))
    }

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .downArrow:
            moveSelection(by: 1)
            return .handled
        case .upArrow:
            moveSelection(by: -1)
            return .handled
        case .space:
            if let task = selectedTask { toggle(task) }
            return .handled
        case .delete:
            if let task = selectedTask { delete(task) }
            return .handled
        case .tab:
            cycleSpace(by: press.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        default:
            break
        }
        switch press.characters {
        case "j":
            moveSelection(by: 1)
        case "k":
            moveSelection(by: -1)
        case "1":
            selectSpace(at: nil)
        case "2", "3", "4", "5", "6", "7", "8", "9":
            // Tab 1 is All, so space n lives on key n+1.
            selectSpace(at: Int(press.characters)! - 2)
        default:
            return .ignored
        }
        return .handled
    }

    private var selectedTask: Task? {
        visible.first { $0.id == selectedID }
    }

    private func moveSelection(by delta: Int) {
        guard !visible.isEmpty else { return }
        guard let current = visible.firstIndex(where: { $0.id == selectedID }) else {
            selectedID = (delta > 0 ? visible.first : visible.last)?.id
            return
        }
        let next = min(max(current + delta, 0), visible.count - 1)
        selectedID = visible[next].id
    }

    // MARK: - Task actions

    private func toggle(_ task: Task) {
        if task.isDone {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                task.completedAt = nil
            }
        } else {
            complete(task)
        }
        try? context.save()
    }

    private func complete(_ task: Task) {
        let id = task.id
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            task.completedAt = .now
            _ = settling.insert(id)
        }
        Sounds.complete()
        // `_Concurrency.` because our model shadows Swift's Task type.
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .seconds(0.7))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                _ = settling.remove(id)
            }
        }
    }

    private func delete(_ task: Task) {
        moveSelection(by: task.id == visible.last?.id ? -1 : 1)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            context.delete(task)
        }
        try? context.save()
    }
}

private struct SpacePill: View {
    let label: String
    let key: String?
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let key {
                    Text(key)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isSelected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary.opacity(0.4)),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
