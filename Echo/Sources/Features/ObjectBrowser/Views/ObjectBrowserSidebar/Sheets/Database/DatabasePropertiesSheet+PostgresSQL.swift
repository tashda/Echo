import SwiftUI
import PostgresKit

// MARK: - PostgreSQL SQL Page

extension DatabasePropertiesSheet {

    @ViewBuilder
    func postgresSQLPage() -> some View {
        if let props = pgProps {
            Section("Generated SQL") {
                let pgSession = session.session as? PostgresSession
                let sql = pgSession?.client.introspection.generateCreateDatabaseSQL(
                    props: props, params: pgParams
                ) ?? ""

                Text(sql)
                    .font(TypographyTokens.monospaced)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SpacingTokens.xs)
            }
        }
    }
}
