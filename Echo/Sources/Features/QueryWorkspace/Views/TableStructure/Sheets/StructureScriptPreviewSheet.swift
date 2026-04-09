import SwiftUI

struct StructureScriptPreviewSheet: View {
    let context: SQLPopoutContext
    let onOpenInWindow: (_ sql: String, _ database: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var formattedSQL: String?

    private var displaySQL: String { formattedSQL ?? context.sql }
    private var canOpenInQueryWindow: Bool {
        !displaySQL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SheetLayoutCustomFooter(title: context.title) {
            ScrollView {
                Text(displaySQL)
                    .font(TypographyTokens.code)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.lg)
            }
            .background(ColorTokens.Background.secondary.opacity(0.5))
        } footer: {
            Button("Copy SQL") {
                PlatformClipboard.copy(displaySQL)
            }
            .buttonStyle(.bordered)
            .disabled(!canOpenInQueryWindow)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Open in Query Window…") {
                onOpenInWindow(displaySQL, context.databaseName)
                dismiss()
            }
            .buttonStyle(.bordered)
            .disabled(!canOpenInQueryWindow)
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 420, idealHeight: 520)
        .task {
            if let formatted = try? await SQLFormatter.shared.format(sql: context.sql, dialect: context.formatterDialect) {
                formattedSQL = formatted
            }
        }
    }
}
