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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 1)
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .focused($internalFocus)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(controlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(borderColor, lineWidth: 0.5)
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
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            accentColor.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 0.6)
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accentColor)
        }
        .frame(width: 26, height: 26)
        .shadow(color: accentColor.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}
