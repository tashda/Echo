import SwiftUI

struct SQLPopoutContext: Identifiable {
    let id = UUID()
    let sql: String
    let title: String
}

struct SQLInspectorPopover: View {
    let context: SQLPopoutContext
    let onOpenInWindow: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(context.title)
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()

                HStack(spacing: SpacingTokens.sm) {
                    Button("Copy SQL") {
                        PlatformClipboard.copy(context.sql)
                    }

                    Button("Open in Query Window") {
                        onOpenInWindow(context.sql)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.lg)
            .padding(.vertical, SpacingTokens.md)

            Divider()

            ScrollView {
                Text(context.sql)
                    .font(TypographyTokens.monospaced)
                    .padding(SpacingTokens.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(ColorTokens.Background.secondary.opacity(0.5))
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct SQLQueryCell: View {
    let sql: String
    let onPopout: (String) -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(sql.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(TypographyTokens.monospaced)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button(action: { onPopout(sql) }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .buttonStyle(.plain)
            .help("Expand SQL")
        }
        .contextMenu {
            Button("Expand SQL") { onPopout(sql) }
            Button("Copy SQL") { PlatformClipboard.copy(sql) }
        }
    }
}

struct SectionInfoButton: View {
    let info: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented) {
            Text(info)
                .font(TypographyTokens.detail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.sm)
                .frame(width: 250)
        }
    }
}
