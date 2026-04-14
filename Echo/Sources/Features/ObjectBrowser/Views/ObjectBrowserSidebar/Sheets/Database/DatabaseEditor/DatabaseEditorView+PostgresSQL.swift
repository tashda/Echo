import SwiftUI
import PostgresKit

// MARK: - PostgreSQL SQL Page

extension DatabaseEditorView {

    @ViewBuilder
    func postgresSQLPage() -> some View {
        let sql = viewModel.pgGenerateFullSQL()
        Section("SQL") {
            if sql.isEmpty {
                Text("No database-level configuration.")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            } else {
                Text(sql)
                    .font(TypographyTokens.monospaced)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.xs)
            }
        }
    }
}
