import SwiftUI
import SwiftData

// One task, full screen inside the panel. The panel keeps the height the list
// had, so pressing → never changes the object you're looking at. More fields
// land in this stack later.
struct TaskDetailView: View {
    @Bindable var task: Task
    var focus: FocusState<PanelView.Focus?>.Binding
    /// Where the task lives, as the list names it ("Inbox" or the space).
    var context: String
    /// Height to hold: the list screen's last measured height.
    var height: CGFloat
    var onBack: () -> Void
    var onToggle: () -> Void

    @AppStorage("learnedDetailEsc") private var learnedEsc = false

    static let margin: CGFloat = 18
    // AppKit-arcana: NSTextView pads its text 5pt; the caret sits ~2.5pt in.
    private static let textViewInset: CGFloat = 5
    private static let caretInset: CGFloat = 2.5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(contextLine)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !learnedEsc {
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .padding(.horizontal, Self.margin)
            .padding(.top, 16)

            TextField("", text: $task.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1...3)
                .strikethrough(task.isDone, color: Color.secondary.opacity(0.6))
                .foregroundStyle(task.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .focused(focus, equals: .detailTitle)
                .onSubmit { focus.wrappedValue = .detailNotes }
                .onExitCommand(perform: back)
                .padding(.horizontal, Self.margin)
                .padding(.top, 6)

            notesEditor
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .frame(height: height, alignment: .top)
        // ⌘↩ completes from either field; Space would just type a space.
        .onKeyPress(keys: [.return]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            onToggle()
            return .handled
        }
    }

    private var contextLine: String {
        task.isDone ? "\(context) \u{00B7} Done" : context
    }

    private func back() {
        learnedEsc = true
        onBack()
    }

    private var notesEditor: some View {
        let notes = Binding(
            get: { task.notes ?? "" },
            set: { task.notes = $0.isEmpty ? nil : $0 }
        )
        return TextEditor(text: notes)
            .textEditorStyle(.plain)
            .font(.system(size: 13))
            .lineSpacing(3)
            .foregroundStyle(.primary)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.never)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if notes.wrappedValue.isEmpty {
                    Text("Notes")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, Self.caretInset)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
            // Fade the last line out when there is more below the fold.
            .mask(
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .focused(focus, equals: .detailNotes)
            .onExitCommand(perform: back)
            .padding(.leading, Self.margin - Self.textViewInset)
            .padding(.trailing, Self.margin)
    }
}
