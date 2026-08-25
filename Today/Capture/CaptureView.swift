import SwiftUI
import SwiftData

struct CaptureView: View {
    static let width: CGFloat = 560
    static let fieldHeight: CGFloat = 64
    static let hintHeight: CGFloat = 32

    static func size(spaceCount: Int) -> CGSize {
        CGSize(width: width, height: fieldHeight + (spaceCount > 0 ? hintHeight : 0))
    }

    var onSave: (String, Space?) -> Void
    var onCancel: () -> Void

    @Query(sort: \Space.sortOrder) private var spaces: [Space]
    @State private var text = ""
    @State private var selectedSpace: Space?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("What needs doing?", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22))
                    .focused($focused)
                    .onSubmit {
                        onSave(text, selectedSpace)
                        text = ""
                    }
                if let selectedSpace {
                    spaceChip(selectedSpace.name)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .frame(height: Self.fieldHeight)

            if !spaces.isEmpty {
                spaceHints
                    .frame(height: Self.hintHeight)
            }
        }
        .frame(width: Self.width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.1))
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedSpace?.id)
        .onExitCommand {
            text = ""
            onCancel()
        }
        .onAppear {
            // Focus lands reliably only after the panel becomes key.
            DispatchQueue.main.async { focused = true }
        }
    }

    private func spaceChip(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.tint.opacity(0.18), in: Capsule())
            .foregroundStyle(.tint)
    }

    private var spaceHints: some View {
        HStack(spacing: 4) {
            // Buttons carry the ⌘-digit shortcuts; they work while the field has focus.
            ForEach(Array(spaces.prefix(9).enumerated()), id: \.element.id) { index, space in
                Button {
                    selectedSpace = selectedSpace?.id == space.id ? nil : space
                } label: {
                    hint(key: "\u{2318}\(index + 1)", label: space.name, isOn: selectedSpace?.id == space.id)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
            Spacer()
            Button {
                selectedSpace = nil
            } label: {
                hint(key: "\u{2318}0", label: "no space", isOn: selectedSpace == nil)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("0", modifiers: .command)
        }
        .padding(.horizontal, 14)
    }

    private func hint(key: String, label: String, isOn: Bool) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(isOn ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear), in: Capsule())
        .contentShape(Capsule())
    }
}
