import SwiftUI
import SwiftData

// The whole app in one floating panel: capture field, space tabs, today list.
struct PanelView: View {
    static let width: CGFloat = 560
    static let cornerRadius: CGFloat = 16
    // Transparent margin around the glass so the shadow has somewhere to land.
    static let shadowInset: CGFloat = 40

    var maxListHeight: CGFloat
    var onDismiss: () -> Void
    var onSizeChange: (CGSize) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    @State private var editingTaskID: UUID?
    @State private var editText = ""

    // Measured from the list's content so the panel is sized by what's in it,
    // not by whatever height the window happens to have right now.
    @State private var listContentHeight: CGFloat = 0

    private enum Focus { case field, list, spaceEditor, taskEditor }
    @FocusState private var focus: Focus?

    // MARK: - Motion

    private func motion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    private var quick: Animation? { motion(.snappy(duration: 0.2)) }

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
            hairline
            tabs
            if visible.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: Self.width)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        // Our own shadow: the window's would follow its rectangle, not the rounded glass.
        .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        .padding(Self.shadowInset)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
        .onAppear {
            // Focus lands reliably only after the panel becomes key.
            DispatchQueue.main.async { focus = .field }
        }
        .onChange(of: focus) { _, focus in
            // Keys must always land somewhere while the panel is up.
            if focus == nil {
                DispatchQueue.main.async { if self.focus == nil { self.focus = .field } }
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(.primary.opacity(0.07))
            .frame(height: 1)
    }

    // MARK: - Field

    private var field: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($focus, equals: .field)
                // Own placeholder: AppKit's shifts ~1pt when the field editor takes over on focus.
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(selectedSpace.map { "Add to \($0.name)" } ?? "What needs doing?")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
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
        .padding(.horizontal, 18)
        .frame(height: 60)
    }

    // MARK: - Tabs

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Pills are plain: the panel is the one glass layer, and glass can't sit on glass.
            HStack(spacing: 2) {
                // Pills carry the ⌘-digit shortcuts, so they fire whatever has focus.
                SpacePill(label: "All", isSelected: selectedSpace == nil) {
                    selectSpace(at: nil)
                }
                .keyboardShortcut("1", modifiers: .command)
                ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
                    let pill = SpacePill(
                        label: space.name,
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
                    TextField("Name", text: $spaceName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 96)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.primary.opacity(0.06), in: Capsule())
                        .focused($focus, equals: .spaceEditor)
                        .onSubmit(commitSpaceEdit)
                        .onExitCommand(perform: cancelSpaceEdit)
                } else {
                    SpacePill(label: "+", isSelected: false) { beginEditing(nil) }
                        .help("New space")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func beginEditing(_ space: Space?) {
        editingSpace = space
        spaceName = space?.name ?? ""
        withAnimation(quick) { isEditingSpace = true }
        DispatchQueue.main.async { focus = .spaceEditor }
    }

    private func commitSpaceEdit() {
        let name = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { cancelSpaceEdit() }
        guard !name.isEmpty else { return }
        withAnimation(quick) {
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
        withAnimation(quick) { isEditingSpace = false }
        editingSpace = nil
        spaceName = ""
        DispatchQueue.main.async { focus = .field }
    }

    private func delete(_ space: Space) {
        if selectedSpace?.id == space.id { selectedSpaceID = "" }
        withAnimation(quick) {
            context.delete(space)
        }
        try? context.save()
    }

    private func selectSpace(at index: Int?) {
        withAnimation(quick) {
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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(rows) { row in
                        switch row {
                        case .header(_, let title):
                            sectionHeader(title)
                        case .task(let task):
                            if editingTaskID == task.id {
                                taskEditor
                            } else {
                                TaskRow(
                                    title: task.title,
                                    isDone: task.isDone,
                                    isSettled: task.isDone && !settling.contains(task.id),
                                    isSelected: task.id == selectedID && focus == .list
                                ) {
                                    selectedID = task.id
                                    focus = .list
                                    toggle(task)
                                }
                                .contextMenu {
                                    Button("Edit") { beginEditing(task) }
                                    Button("Delete", role: .destructive) { delete(task) }
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .animation(quick, value: rows.map(\.id))
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listContentHeight = $0 }
            }
            .onChange(of: selectedID) { _, id in
                // No anchor = scroll only as far as needed to reveal the row.
                guard let id, focus == .list else { return }
                withAnimation(quick) { proxy.scrollTo(id.uuidString) }
            }
            .onChange(of: focus) { _, focus in
                if focus == .field, let first = rows.first {
                    withAnimation(quick) { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: min(listContentHeight, maxListHeight))
        .focusable()
        .focusEffectDisabled()
        .focused($focus, equals: .list)
        .onKeyPress(action: handleListKey)
        .onExitCommand(perform: onDismiss)
    }

    private var taskEditor: some View {
        HStack(spacing: 10) {
            Circle()
                .strokeBorder(.secondary.opacity(0.55), lineWidth: 1.5)
                .frame(width: 18, height: 18)
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focus, equals: .taskEditor)
                .onSubmit(commitTaskEdit)
                .onExitCommand(perform: cancelTaskEdit)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.selection.opacity(0.85))
        )
    }

    private func beginEditing(_ task: Task) {
        selectedID = task.id
        editText = task.title
        editingTaskID = task.id
        DispatchQueue.main.async { focus = .taskEditor }
    }

    private func commitTaskEdit() {
        defer { cancelTaskEdit() }
        let title = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let task = tasks.first(where: { $0.id == editingTaskID }) else { return }
        task.title = title
        try? context.save()
    }

    private func cancelTaskEdit() {
        editingTaskID = nil
        editText = ""
        // The editor is being torn down this pass; focus only sticks after it's gone.
        DispatchQueue.main.async { focus = .list }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 3)
    }

    private var emptyState: some View {
        Text(selectedSpace.map { "Nothing in \($0.name)" } ?? "All clear")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }

    // MARK: - Keyboard

    private func enterList() {
        guard !visible.isEmpty else { return }
        if selectedTask == nil { selectedID = visible.first?.id }
        focus = .list
    }

    private func handleListKey(_ press: KeyPress) -> KeyPress.Result {
        // Ancestors see descendants' key presses too; leave the inline editor alone.
        guard focus == .list else { return .ignored }
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
        case .delete, .deleteForward:
            if let task = selectedTask { delete(task) }
            return .handled
        case .tab:
            cycleSpace(by: press.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        case .return:
            if let task = selectedTask { beginEditing(task) }
            return .handled
        default:
            break
        }
        switch press.characters {
        case "j":
            moveSelection(by: 1)
        case "k":
            moveSelection(by: -1)
        case "\u{7F}", "\u{8}":
            // Backspace arrives as a raw DEL/BS character on some paths.
            if let task = selectedTask { delete(task) }
        default:
            // Any other *printable* character jumps back to the field with it.
            guard press.modifiers.isSubset(of: [.shift]),
                  press.characters.count == 1,
                  let char = press.characters.first,
                  let scalar = char.unicodeScalars.first,
                  !scalar.properties.generalCategory.isControl
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
        withAnimation(motion(.spring(response: 0.3, dampingFraction: 0.85))) {
            context.insert(Task(title: trimmed, space: selectedSpace))
            text = ""
        }
        try? context.save()
    }

    private func toggle(_ task: Task) {
        if task.isDone {
            withAnimation(motion(.spring(response: 0.3, dampingFraction: 0.8))) {
                task.completedAt = nil
            }
        } else {
            complete(task)
        }
        try? context.save()
    }

    private func complete(_ task: Task) {
        let id = task.id
        withAnimation(motion(.spring(response: 0.28, dampingFraction: 0.62))) {
            task.completedAt = .now
            _ = settling.insert(id)
        }
        Sounds.complete()
        // `_Concurrency.` because our model shadows Swift's Task type.
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .seconds(0.65))
            withAnimation(motion(.spring(response: 0.45, dampingFraction: 0.85))) {
                _ = settling.remove(id)
            }
        }
    }

    private func delete(_ task: Task) {
        moveSelection(by: task.id == visible.last?.id ? -1 : 1)
        withAnimation(motion(.spring(response: 0.3, dampingFraction: 0.85))) {
            context.delete(task)
        }
        try? context.save()
    }
}

private extension Unicode.GeneralCategory {
    var isControl: Bool {
        switch self {
        case .control, .format, .surrogate, .privateUse, .unassigned: true
        default: false
        }
    }
}

private struct SpacePill: View {
    let label: String
    let isSelected: Bool
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
    }

    private var fill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.tint.opacity(0.18)) }
        if isHovered { return AnyShapeStyle(.primary.opacity(0.06)) }
        return AnyShapeStyle(.clear)
    }
}
