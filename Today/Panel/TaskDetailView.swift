import SwiftUI
import SwiftData

// One task, full screen inside the panel: title, where it lives, and notes.
// More fields land here as rows later.
struct TaskDetailView: View {
    @Bindable var task: Task
    var focus: FocusState<PanelView.Focus?>.Binding
    var maxNotesHeight: CGFloat
    var onBack: () -> Void
    var onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Leading edge of the title text: back button + checkmark + spacings.
    private static let titleInset: CGFloat = 18 + 22 + 12 + 18 + 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Text(meta)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, Self.titleInset)
                .padding(.bottom, 12)
            Rectangle()
                .fill(.primary.opacity(0.07))
                .frame(height: 1)
            notesEditor
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Back (Esc)")

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
                .frame(width: 18, height: 18)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.62), value: task.isDone)

            TextField("", text: $task.title)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold))
                .strikethrough(task.isDone, color: .secondary)
                .foregroundStyle(task.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .focused(focus, equals: .detailTitle)
                .onSubmit { focus.wrappedValue = .detailNotes }
                .onExitCommand(perform: onBack)
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
    }

    private var meta: String {
        let added = task.createdAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(task.space?.name ?? "Inbox") \u{00B7} Added \(added)"
    }

    private var notesEditor: some View {
        let notes = Binding(
            get: { task.notes ?? "" },
            set: { task.notes = $0.isEmpty ? nil : $0 }
        )
        let lines = notes.wrappedValue.components(separatedBy: "\n").count
        let height = min(maxNotesHeight, max(140, CGFloat(lines) * 18 + 24))
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
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
            .focused(focus, equals: .detailNotes)
            .onExitCommand(perform: onBack)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
    }
}
