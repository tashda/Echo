import SwiftUI

/// Reusable SQL preview component for editor windows, wizards, and anywhere
/// that displays generated or read-only SQL. Shows a header with copy button
/// and an optional "Open in Query Window" action.
struct SQLPreviewSection: View {
    let sql: String
    var title: String = "Generated SQL"
    var onOpenInQueryWindow: ((String) -> Void)?

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "doc.text")
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(title)
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
            Spacer()

            if let onOpenInQueryWindow {
                Button {
                    onOpenInQueryWindow(sql)
                } label: {
                    Label("Open in Query Window", systemImage: "arrow.up.right.square")
                        .font(TypographyTokens.caption)
                }
                .buttonStyle(.borderless)
            }

            copyButton
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }

    private var content: some View {
        ScrollView {
            Text(sql)
                .font(TypographyTokens.code)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.md)
        }
    }

    private var copyButton: some View {
        Button {
            PlatformClipboard.copy(sql)
            didCopy = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                didCopy = false
            }
        } label: {
            Label(
                didCopy ? "Copied" : "Copy",
                systemImage: didCopy ? "checkmark" : "doc.on.doc"
            )
            .font(TypographyTokens.caption)
        }
        .buttonStyle(.borderless)
    }
}
