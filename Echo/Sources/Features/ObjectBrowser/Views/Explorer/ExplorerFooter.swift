import SwiftUI
import EchoSense

struct ExplorerFooterSearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let controlBackground: Color
    let borderColor: Color
    let height: CGFloat

    @FocusState private var internalFocus: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorTokens.Text.secondary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.vertical, SpacingTokens.xxxs)
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .focused($internalFocus)
            }
        }
        .padding(.horizontal, SpacingTokens.xs2)
        .padding(.vertical, SpacingTokens.xxxs)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(controlBackground)
        )
        .overlay(
            Group {
                if internalFocus {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(ColorTokens.accent.opacity(0.18), lineWidth: 0.8)
                }
            }
        )
        .onChange(of: internalFocus) { _, newValue in
            guard newValue != isFocused else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isFocused = newValue
            }
        }
        .onChange(of: isFocused) { _, newValue in
            guard newValue != internalFocus else { return }
            internalFocus = newValue
        }
    }
}

struct ExplorerFooterActionButton: View {
    let accentColor: Color

    var body: some View {
        Image(systemName: "plus")
            .font(TypographyTokens.standard)
            .foregroundStyle(ColorTokens.Text.secondary)
            .frame(width: 24, height: 24)
    }
}
