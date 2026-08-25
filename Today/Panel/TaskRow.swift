import SwiftUI

struct TaskRow: View {
    let title: String
    let isDone: Bool
    let isSelected: Bool
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            checkmark
            Text(title)
                .font(.system(size: 13))
                .strikethrough(isDone, color: .secondary)
                .foregroundStyle(isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(.selection.opacity(0.8)) : AnyShapeStyle(.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .strokeBorder(.tertiary, lineWidth: 1.5)
                .opacity(isDone ? 0 : 1)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .scaleEffect(isDone ? 1 : 0.4)
                .opacity(isDone ? 1 : 0)
        }
        .frame(width: 17, height: 17)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isDone)
    }
}
