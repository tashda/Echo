import SwiftUI

// MARK: - SQL Block

struct InspectorSQLBlock: View {
    let sql: String
    let onOpenInTab: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack {
                Text("SQL")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Button {
                    copyToGeneralPasteboard(sql)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(TypographyTokens.compact)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .help("Copy SQL")

                Button {
                    onOpenInTab()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(TypographyTokens.compact)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.accent)
                .help("Open in Query Tab")
            }

            Text(sql)
                .font(TypographyTokens.Table.sql)
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.xs)
                .background(
                    RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                        .fill(ColorTokens.Text.secondary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.xs2, style: .continuous)
                                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18), lineWidth: 0.6)
                        )
                )
                .textSelection(.enabled)
                .contextMenu {
                    Button { copyToGeneralPasteboard(sql) } label: {
                        Label("Copy SQL", systemImage: "doc.on.doc")
                    }
                    Button { onOpenInTab() } label: {
                        Label("Open in Query Tab", systemImage: "arrow.up.right.square")
                    }
                }
        }
    }
}

func copyToGeneralPasteboard(_ value: String) {
#if os(macOS)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
#else
    let pasteboard = UIPasteboard.general
    pasteboard.string = value
#endif
}
