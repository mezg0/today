import SwiftUI
import SwiftData

// The whole app in one floating panel: capture field, space tabs, today list.
struct PanelView: View {
    static let width: CGFloat = 560

    var onDismiss: () -> Void
    var onSizeChange: (CGSize) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Task.createdAt, order: .reverse) private var tasks: [Task]
    @Query(sort: \Space.sortOrder) private var spaces: [Space]
    @AppStorage("selectedSpaceID") private var selectedSpaceID = ""

    @State private var text = ""
    @State private var selectedID: UUID?
    // Tasks that were just completed: they keep their spot in the list for a
    // beat so the checkmark can land before the row settles down to Done.
    @State private var settling: Set<UUID> = []

    @State private var isEditingSpace = false
    @State private var editingSpace: Space?
    @State private var spaceName = ""

    private enum Focus { case field, list, spaceEditor }
    @FocusState private var focus: Focus?

    // MARK: - Derived data

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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            field
            tabs
            if visible.isEmpty {
                emptyState
            } else {
                list
            }
            footer
        }
        .frame(width: Self.width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.1))
        )
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
        .onAppear {
            // Focus lands reliably only after the panel becomes key.
            DispatchQueue.main.async { focus = .field }
        }
    }

    private var field: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(selectedSpace.map { "Add to \($0.name)" } ?? "What needs doing?", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 22))
                .focused($focus, equals: .field)
                .onSubmit(addTask)
                .onKeyPress(.downArrow) {
                    enterList()
                    return .handled
                }
                .onKeyPress(keys: [.tab]) { press in
                    cycleSpace(by: press.modifiers.contains(.shift) ? -1 : 1)
                    return .handled
                }
                .onExitCommand {
                    if text.isEmpty {
                        onDismiss()
                    } else {
                        text = ""
                    }
                }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
    }

    // MARK: - Tabs

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Pills carry the ⌘-digit shortcuts, so they fire whatever has focus.
                SpacePill(label: "All", key: "1", isSelected: selectedSpace == nil) {
                    selectSpace(at: nil)
                }
                .keyboardShortcut("1", modifiers: .command)
                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    let pill = SpacePill(
                        label: space.name,
                        key: index < 8 ? "\(index + 2)" : nil,
                        isSelected: selectedSpace?.id == space.id
                    ) {
                        selectSpace(at: index)
                    }
                    .contextMenu {
                        Button("Rename") { beginEditing(space) }
                        Button("Delete Space", role: .destructive) { delete(space) }
                    }
                    if index < 8 {
                        pill.keyboardShortcut(KeyEquivalent(Character(String(index + 2))), modifiers: .command)
                    } else {
                        pill
                    }
                }
                if isEditingSpace {
                    TextField("Space name", text: $spaceName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 100)
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
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
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
        focus = .field
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
        if focus == .list { focus = .field }
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
                            isSelected: task.id == selectedID && focus == .list
                        ) {
                            selectedID = task.id
                            focus = .list
                            toggle(task)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: 440)
        .focusable()
        .focusEffectDisabled()
        .focused($focus, equals: .list)
        .onKeyPress(action: handleListKey)
        .onExitCommand(perform: onDismiss)
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
        Text("All clear")
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            hint("\u{2193}", "list")
            hint("\u{2318}1\u{2013}9", "tabs")
            hint("space", "done")
            hint("\u{232B}", "delete")
            Spacer()
            hint("esc", "close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.25))
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Keyboard

    private func enterList() {
        guard !visible.isEmpty else { return }
        if selectedTask == nil { selectedID = visible.first?.id }
        focus = .list
    }

    private func handleListKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .downArrow:
            moveSelection(by: 1)
            return .handled
        case .upArrow:
            if visible.firstIndex(where: { $0.id == selectedID }) == 0 {
                focus = .field
            } else {
                moveSelection(by: -1)
            }
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
        case .return:
            focus = .field
            return .handled
        default:
            break
        }
        switch press.characters {
        case "j":
            moveSelection(by: 1)
        case "k":
            moveSelection(by: -1)
        default:
            // Any other typed character jumps back to the field with it.
            guard press.modifiers.isSubset(of: [.shift]),
                  press.characters.count == 1,
                  let char = press.characters.first, !char.isNewline
            else { return .ignored }
            text.append(char)
            focus = .field
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

    private func addTask() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            context.insert(Task(title: trimmed, space: selectedSpace))
            text = ""
        }
        try? context.save()
    }

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
