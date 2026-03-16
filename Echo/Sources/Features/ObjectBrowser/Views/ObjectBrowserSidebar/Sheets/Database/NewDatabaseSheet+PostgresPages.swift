import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Pages

extension NewDatabaseSheet {

    @ViewBuilder
    func postgresGeneralPage() -> some View {
        Section("Database") {
            LabeledContent("Name") {
                TextField("new_database", text: $databaseName)
                    .frame(width: 200)
            }

            Picker("Owner", selection: $owner) {
                Text("(default)").tag("")
                ForEach(pgRoles, id: \.self) { role in
                    Text(role).tag(role)
                }
            }

            LabeledContent("Comment") {
                TextField("", text: $pgComment, axis: .vertical)
                    .lineLimit(1...3)
            }
        }

        Section("Template") {
            Picker("Template", selection: Binding(
                get: { pgTemplate ?? "" },
                set: { pgTemplate = $0.isEmpty ? nil : $0 }
            )) {
                Text("(default)").tag("")
                ForEach(pgTemplates, id: \.self) { t in
                    Text(t).tag(t)
                }
            }
        }
    }

    @ViewBuilder
    func postgresDefinitionPage() -> some View {
        Section("Character Set") {
            Picker("Encoding", selection: $pgEncoding) {
                ForEach(pgEncodings, id: \.self) { enc in
                    Text(enc).tag(enc)
                }
            }

            Picker("Locale Provider", selection: $pgLocaleProvider) {
                Text("libc").tag("libc")
                Text("icu").tag("icu")
            }

            if pgLocaleProvider == "libc" {
                LabeledContent("Collation") {
                    TextField("e.g. en_US.UTF-8", text: $pgCollation)
                        .frame(width: 200)
                }

                LabeledContent("Character Type") {
                    TextField("e.g. en_US.UTF-8", text: $pgCtype)
                        .frame(width: 200)
                }
            } else {
                LabeledContent("ICU Locale") {
                    TextField("e.g. en-US", text: $pgIcuLocale)
                        .frame(width: 200)
                }

                LabeledContent("ICU Rules") {
                    TextField("", text: $pgIcuRules)
                        .frame(width: 200)
                }
            }
        }

        Section("Tablespace") {
            Picker("Tablespace", selection: $pgTablespace) {
                ForEach(pgTablespaces, id: \.self) { ts in
                    Text(ts).tag(ts)
                }
            }
        }

        Section("Connection") {
            LabeledContent("Connection Limit") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $pgConnectionLimit, format: .number)
                        .frame(width: 60)
                    Text("-1 = unlimited")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            Toggle("Is Template", isOn: $pgIsTemplate)
            Toggle("Allow Connections", isOn: $pgAllowConnections)
        }

        Section("Strategy") {
            Picker("Creation Strategy", selection: $pgStrategy) {
                Text("WAL Log").tag("wal_log")
                Text("File Copy").tag("file_copy")
            }
        }
    }
}
