import AppKit
import SwiftUI
import SwiftData

// The whole app in one floating panel: capture field, space tabs, today list.
struct PanelView: View {
    static let width: CGFloat = 560
    static let cornerRadius: CGFloat = 16
    // One shape for the glass, the clip, and the hosting-layer mask — they must agree.
    static let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    var maxListHeight: CGFloat
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

    // Which task's screen is pushed over the list, if any.
    @State private var detailTaskID: UUID?

    // Measured from the list's content so the panel is sized by what's in it,
    // not by whatever height the window happens to have right now.
    @State private var listContentHeight: CGFloat = 0
    // The list screen's height, held by the task screen so → never resizes the panel.
    @State private var listScreenHeight: CGFloat = 0

    enum Focus { case field, list, spaceEditor, detailTitle, detailNotes }
    @FocusState private var focus: Focus?
    // Set while a deliberate re-home is queued, so the nil-focus net stays out of the way.
    @State private var focusRestorePending = false

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
        // Duplicate ids are possible after a CloudKit merge; never trap on them.
        let order = Dictionary(spaces.enumerated().map { ($1.id, $0 + 1) }, uniquingKeysWith: { a, _ in a })
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
        // Once everything is done, the Done rows give way to a one-line summary.
        guard !active.isEmpty else { return [] }
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

    private var detailTask: Task? {
        tasks.first { $0.id == detailTaskID }
    }

    var body: some View {
        Group {
            if let task = detailTask {
                TaskDetailView(
                    task: task,
                    focus: $focus,
                    context: task.space?.name ?? "Inbox",
                    height: max(listScreenHeight, 160),
                    onBack: closeDetail,
                    onToggle: { toggle(task) }
                )
            } else {
                listScreen
            }
        }
        .frame(width: Self.width)
        .glassEffect(.regular, in: Self.shape)
        .clipShape(Self.shape)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
        .onAppear {
            // Focus lands reliably only after the panel becomes key.
            DispatchQueue.main.async { focus = .field }
        }
        .onChange(of: focus) { old, focus in
            if old == .detailNotes || old == .detailTitle { try? context.save() }
            // Keys must always land somewhere while the panel is up.
            if focus == nil, !focusRestorePending {
                DispatchQueue.main.async {
                    if self.focus == nil, !focusRestorePending {
                        restoreKeyboard(to: detailTaskID == nil ? .field : .detailNotes)
                    }
                }
            }
        }
    }

    private var listScreen: some View {
        // Derived once per pass; the filters and sort aren't free on every keystroke.
        let rows = self.rows
        return VStack(spacing: 0) {
            field
            hairline
            tabs
            if rows.isEmpty {
                emptyState
            } else {
                list(rows: rows)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listScreenHeight = $0 }
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
        ScrollView(.horizontal) {
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
        .scrollIndicators(.never)
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
        do {
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
        focusRestorePending = true
        focus = nil
        isEditingSpace = false
        editingSpace = nil
        spaceName = ""
        DispatchQueue.main.async { restoreKeyboard(to: .field) }
    }

    private func delete(_ space: Space) {
        if selectedSpace?.id == space.id { selectedSpaceID = "" }
        do {
            context.delete(space)
        }
        try? context.save()
    }

    private func selectSpace(at index: Int?) {
        do {
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

    private func list(rows: [Row]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(rows) { row in
                        switch row {
                        case .header(_, let title):
                            sectionHeader(title)
                        case .task(let task):
                            TaskRow(
                                title: task.title,
                                isDone: task.isDone,
                                isSettled: task.isDone && !settling.contains(task.id),
                                isSelected: task.id == selectedID && focus == .list,
                                hasNotes: !(task.notes ?? "").isEmpty,
                                onOpen: { openDetail(task) }
                            ) {
                                selectedID = task.id
                                focus = .list
                                toggle(task)
                            }
                            .contextMenu {
                                Button("Open") { openDetail(task) }
                                Button("Delete", role: .destructive) { delete(task) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listContentHeight = $0 }
            }
            .onChange(of: selectedID) { _, id in
                // No anchor = scroll only as far as needed to reveal the row.
                guard let id, focus == .list else { return }
                do { proxy.scrollTo(id.uuidString) }
            }
            .onChange(of: focus) { _, focus in
                if focus == .field, let first = rows.first {
                    do { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
        .scrollIndicators(.never)
        .frame(height: min(listContentHeight, maxListHeight))
        .focusable()
        .focusEffectDisabled()
        .focused($focus, equals: .list)
        .onKeyPress(action: handleListKey)
        .onExitCommand(perform: onDismiss)
    }

    // MARK: - Detail screen

    private func openDetail(_ task: Task) {
        selectedID = task.id
        focusRestorePending = true
        focus = nil
        detailTaskID = task.id
        // The screen exists only after the next pass; focus sticks then.
        DispatchQueue.main.async { restoreKeyboard(to: .detailTitle) }
    }

    private func closeDetail() {
        guard let task = detailTask else { return }
        if task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.title = "Untitled"
        }
        try? context.save()
        focusRestorePending = true
        focus = nil
        detailTaskID = nil
        // The list exists only after the next pass; focus sticks then.
        DispatchQueue.main.async { restoreKeyboard(to: .list) }
    }

    // AppKit-arcana: tearing down a focused NSTextView leaves the panel with a
    // dead first responder, and @FocusState alone will not bring it back.
    private func restoreKeyboard(to target: Focus) {
        focusRestorePending = false
        NSApp.keyWindow?.makeFirstResponder(nil)
        focus = target
        DispatchQueue.main.async {
            if focus == nil { focus = detailTaskID == nil ? .field : .detailNotes }
        }
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
        let base = selectedSpace.map { "Nothing in \($0.name)" } ?? "All clear"
        let doneCount = done.count
        return Text(doneCount > 0 ? "\(base) \u{00B7} \(doneCount) done today" : base)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }

    // MARK: - Keyboard

    private func enterList() {
        guard !visible.isEmpty else { return }
        // Coming from the field always starts at the top, not wherever the highlight was left.
        selectedID = visible.first?.id
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
            // ⌘⌫ deletes; a bare Backspace is too easy to hit by reflex.
            guard press.modifiers.contains(.command) else { return .handled }
            if let task = selectedTask { delete(task) }
            return .handled
        case .tab:
            cycleSpace(by: press.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        case .return:
            if let task = selectedTask { openDetail(task) }
            return .handled
        default:
            break
        }
        if press.modifiers.contains(.command), press.characters == "s" {
            if let task = selectedTask, !task.isDone { snooze(task) }
            return .handled
        }
        if press.modifiers.contains(.command), press.characters == "z" {
            // ⌫ is one keystroke from data loss; ⌘Z brings it back.
            context.undoManager?.undo()
            try? context.save()
            return .handled
        }
        switch press.characters {
        case "j":
            moveSelection(by: 1)
        case "k":
            moveSelection(by: -1)
        case "\u{7F}", "\u{8}":
            // Backspace arrives as a raw DEL/BS character on some paths.
            guard press.modifiers.contains(.command) else { return .handled }
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
        do {
            context.insert(Task(title: trimmed, space: selectedSpace))
            text = ""
        }
        try? context.save()
    }

    private func toggle(_ task: Task) {
        if task.isDone {
            do {
                task.completedAt = nil
            }
        } else {
            complete(task)
        }
        try? context.save()
    }

    private func complete(_ task: Task) {
        let id = task.id
        do {
            task.completedAt = .now
            _ = settling.insert(id)
        }
        Sounds.complete()
        // `_Concurrency.` because our model shadows Swift's Task type.
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .seconds(0.65))
            do {
                _ = settling.remove(id)
            }
        }
    }

    private func delete(_ task: Task) {
        moveHighlightOff(task)
        context.delete(task)
        try? context.save()
    }

    /// Hide until tomorrow. It comes back at the top of its space with the day.
    private func snooze(_ task: Task) {
        moveHighlightOff(task)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        task.snoozedUntil = Calendar.current.startOfDay(for: tomorrow)
        try? context.save()
    }

    /// When a row is about to leave the list, give the highlight a new home.
    private func moveHighlightOff(_ task: Task) {
        guard selectedID == task.id, let index = visible.firstIndex(where: { $0.id == task.id }) else { return }
        let remaining = visible.filter { $0.id != task.id }
        selectedID = remaining.indices.contains(index) ? remaining[index].id : remaining.last?.id
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
    }

    private var fill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.tint.opacity(0.18)) }
        if isHovered { return AnyShapeStyle(.primary.opacity(0.06)) }
        return AnyShapeStyle(.clear)
    }
}
