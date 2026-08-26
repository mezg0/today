import SwiftUI
import SwiftData

// One task, full screen inside the panel: the row you came from, with notes
// under it. Nothing else. Esc goes back.
struct TaskDetailView: View {
    @Bindable var task: Task
    var focus: FocusState<PanelView.Focus?>.Binding
    var maxNotesHeight: CGFloat
    var onBack: () -> Void
    var onToggle: () -> Void

    private static let margin: CGFloat = 18
    private static let checkSize: CGFloat = 18
    /// Left edge shared by the title and the notes.
    private static let textInset: CGFloat = margin + checkSize + 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
            notesEditor
        }
        .padding(.top, 18)
        .padding(.bottom, 16)
        .overlay(alignment: .topTrailing) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.quaternary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Back (Esc)")
            .padding(8)
        }
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
                .font(.system(size: 15, weight: .medium))
                .strikethrough(task.isDone, color: .secondary)
                .foregroundStyle(task.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .focused(focus, equals: .detailTitle)
                .onSubmit { focus.wrappedValue = .detailNotes }
                .onExitCommand(perform: onBack)
        }
        .padding(.horizontal, Self.margin)
        .padding(.trailing, 24)
    }

    private var notesEditor: some View {
        let notes = Binding(
            get: { task.notes ?? "" },
            set: { task.notes = $0.isEmpty ? nil : $0 }
        )
        let lineHeight: CGFloat = 19
        let lines = max(2, notes.wrappedValue.components(separatedBy: "\n").count)
        let height = min(maxNotesHeight, CGFloat(lines) * lineHeight + 8)
        return TextEditor(text: notes)
            .textEditorStyle(.plain)
            .font(.system(size: 13))
            .lineSpacing(3)
            .foregroundStyle(.secondary)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                if notes.wrappedValue.isEmpty {
                    Text("Notes")
                        .font(.system(size: 13))
                        .foregroundStyle(.quaternary)
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
            .padding(.top, 4)
    }
}
