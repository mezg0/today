import SwiftUI

struct TaskRow: View {
    // Shared with the inline editor so it sits exactly where the row was.
    static let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 7
    static let selectionOpacity = 0.85
    /// Distance from the row's leading edge to the title text.
    static let titleInset: CGFloat = horizontalPadding + 18 + 10

    let title: String
    let isDone: Bool
    let isSettled: Bool
    let isSnoozed: Bool
    let isSelected: Bool
    let hasNotes: Bool
    var onOpen: () -> Void
    var onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            checkmark
            Text(title)
                .font(.system(size: 13))
                .strikethrough(isDone, color: .secondary)
                .foregroundStyle(isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(2)
            if hasNotes {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if isSnoozed {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .background(Self.shape.fill(rowFill))
        .opacity(isSettled ? 0.55 : 1)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onToggle)
    }

    private var rowFill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.selection.opacity(Self.selectionOpacity)) }
        if isHovered { return AnyShapeStyle(.primary.opacity(0.05)) }
        return AnyShapeStyle(.clear)
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .strokeBorder(.secondary.opacity(0.55), lineWidth: 1.5)
                .opacity(isDone ? 0 : 1)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .scaleEffect(isDone ? 1 : 0.5)
                .opacity(isDone ? 1 : 0)
        }
        .frame(width: 18, height: 18)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isDone)
    }
}
