import SwiftUI
import AppKit

struct ScriptPreviewSheet: View {
    let statements: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private var scriptText: String {
        statements.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(scriptText)
                    .font(TypographyTokens.monospaced)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.md)
            }
            .background(ColorTokens.Background.secondary)

            Divider()

            toolbar
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 320, idealHeight: 440)
        .navigationTitle("Script Preview")
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(scriptText, forType: .string)
                didCopy = true
            } label: {
                Label(
                    didCopy ? "Copied" : "Copy to Clipboard",
                    systemImage: didCopy ? "checkmark" : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.bar)
    }
}
