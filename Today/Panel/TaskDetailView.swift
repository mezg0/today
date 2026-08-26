import SwiftUI
import SwiftData

// One task, full screen inside the panel: title, notes. Esc goes back.
struct TaskDetailView: View {
    @Bindable var task: Task
    var focus: FocusState<PanelView.Focus?>.Binding
    var maxNotesHeight: CGFloat
    var onBack: () -> Void

    private static let margin: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("", text: $task.title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .strikethrough(task.isDone, color: .secondary)
                .foregroundStyle(task.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .focused(focus, equals: .detailTitle)
                .onSubmit { focus.wrappedValue = .detailNotes }
                .onExitCommand(perform: onBack)
                .padding(.horizontal, Self.margin)
            notesEditor
        }
        .padding(.top, 18)
        .padding(.bottom, 16)
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
            .padding(.leading, Self.margin - 5)
            .padding(.trailing, Self.margin)
    }
}
