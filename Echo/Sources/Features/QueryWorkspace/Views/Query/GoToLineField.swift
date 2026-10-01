import SwiftUI

/// Round 28.9 (GL1): ⌘L opens this small glass field at the top of the editor; Return jumps,
/// Escape closes. It replaces the Go to Line alert.
struct GoToLineField: View {
    let lineCount: Int
    let onGo: (Int) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .foregroundStyle(ColorTokens.Text.secondary)
            TextField("Line", text: $text, prompt: Text("Line (1 to \(lineCount))"))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    if let line = Int(text.trimmingCharacters(in: .whitespaces)), line >= 1 { onGo(min(line, lineCount)) } else { onCancel() }
                }
                .onExitCommand(perform: onCancel)
            Text(verbatim: "↩").foregroundStyle(ColorTokens.Text.tertiary)
        }
        .font(TypographyTokens.standard)
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs2)
        .frame(width: LayoutTokens.EditorGutter.goToLineWidth)
        .glassEffect(.regular, in: .capsule)
        .padding(SpacingTokens.xxs)
        .onAppear { isFocused = true }
    }
}
