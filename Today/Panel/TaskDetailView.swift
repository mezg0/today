import SwiftUI
import SwiftData

// One task, full screen inside the panel. A small bar to go back, then one
// block aligned to a single left edge: title, notes, and where it came from.
// More fields land in that block later.
struct TaskDetailView: View {
    @Bindable var task: Task
    var focus: FocusState<PanelView.Focus?>.Binding
    /// Name of the list Esc returns to ("All" or a space).
    var backLabel: String
    /// Whether the list being returned to mixes spaces, so the space is worth stating.
    var showsSpace: Bool
    var maxNotesHeight: CGFloat
    var onBack: () -> Void
    var onToggle: () -> Void

    private static let margin: CGFloat = 18
    private static let checkSize: CGFloat = 18
    /// Left edge shared by the title, notes, and footer line.
    private static let textInset: CGFloat = margin + checkSize + 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            Rectangle()
                .fill(.primary.opacity(0.07))
                .frame(height: 1)
            titleRow
                .padding(.top, 14)
            notesEditor
                .padding(.top, 2)
            Text(footer)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.leading, Self.textInset)
                .padding(.top, 8)
                .padding(.bottom, 14)
        }
    }

    private var topBar: some View {
        Button(action: onBack) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text(backLabel)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Back (Esc)")
        .padding(.horizontal, Self.margin)
        .frame(height: 38)
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(.secondary.opacity(0.55), lineWidth: 1.5)
                        .opacity(task.isDone ? 0 : 1)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.tint)
                        .scaleEffect(task.isDone ? 1 : 0.5)
                        .opacity(task.isDone ? 1 : 0)
                }
                .frame(width: Self.checkSize, height: Self.checkSize)
                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: task.isDone)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)

            TextField("", text: $task.title)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .strikethrough(task.isDone, color: .secondary)
                .foregroundStyle(task.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .focused(focus, equals: .detailTitle)
                .onSubmit { focus.wrappedValue = .detailNotes }
                .onExitCommand(perform: onBack)
        }
        .padding(.horizontal, Self.margin)
    }

    private var footer: String {
        let added = "Added " + task.createdAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        guard showsSpace else { return added }
        return "\(task.space?.name ?? "Inbox") \u{00B7} \(added)"
    }

    private var notesEditor: some View {
        let notes = Binding(
            get: { task.notes ?? "" },
            set: { task.notes = $0.isEmpty ? nil : $0 }
        )
        let lineHeight: CGFloat = 19
        let lines = max(3, notes.wrappedValue.components(separatedBy: "\n").count)
        let height = min(maxNotesHeight, CGFloat(lines) * lineHeight + 8)
        return TextEditor(text: notes)
            .textEditorStyle(.plain)
            .font(.system(size: 13))
            .lineSpacing(3)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                if notes.wrappedValue.isEmpty {
                    Text("Notes")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        // The text view starts its text (and caret) a hair in from its edge.
                        .padding(.leading, 2.5)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
            .focused(focus, equals: .detailNotes)
            .onExitCommand(perform: onBack)
            // Pull the text view's own inset back so the text sits on the title's edge.
            .padding(.leading, Self.textInset - 5)
            .padding(.trailing, Self.margin)
    }
}
