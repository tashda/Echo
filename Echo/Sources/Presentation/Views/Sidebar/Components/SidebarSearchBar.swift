import SwiftUI

struct SidebarSearchBar<Accessory: View>: View {
    let placeholder: String
    @Binding var text: String
    var isDisabled: Bool
    var showsClearButton: Bool
    var onClear: (() -> Void)?
    var focusBinding: FocusState<Bool>.Binding?
    var clearShortcut: KeyboardShortcut?
    @ViewBuilder var accessory: Accessory

    init(
        placeholder: String,
        text: Binding<String>,
        isDisabled: Bool = false,
        showsClearButton: Bool,
        onClear: (() -> Void)? = nil,
        focusBinding: FocusState<Bool>.Binding? = nil,
        clearShortcut: KeyboardShortcut? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isDisabled = isDisabled
        self.showsClearButton = showsClearButton
        self.onClear = onClear
        self.focusBinding = focusBinding
        self.clearShortcut = clearShortcut
        self.accessory = accessory()
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                searchField

                if showsClearButton, let onClear {
                    clearButton(onClear: onClear)
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1, height: 18)
                    .opacity(isDisabled ? 0.35 : 1)

                accessory
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .padding(12)
    }

    @ViewBuilder
    private var searchField: some View {
        let field = TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .disabled(isDisabled)

        if let focusBinding {
            field.focused(focusBinding)
        } else {
            field
        }
    }

    @ViewBuilder
    private func clearButton(onClear: @escaping () -> Void) -> some View {
        let button = Button(action: onClear) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)

        if let clearShortcut {
            button.keyboardShortcut(clearShortcut)
        } else {
            button
        }
    }
}
