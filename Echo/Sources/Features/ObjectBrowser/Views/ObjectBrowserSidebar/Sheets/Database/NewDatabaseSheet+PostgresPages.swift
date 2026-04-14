import SwiftUI
import PostgresKit

// MARK: - PostgreSQL Pages

extension NewDatabaseSheet {

    @ViewBuilder
    func postgresGeneralPage() -> some View {
        Section("Database") {
            PropertyRow(title: "Name") {
                TextField("", text: $databaseName, prompt: Text("new_database"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Owner") {
                Picker("", selection: $owner) {
                    Text("(default)").tag("")
                    ForEach(pgRoles, id: \.self) { role in
                        Text(role).tag(role)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Comment") {
                TextField("", text: $pgComment, prompt: Text("Optional comment"), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Template") {
            PropertyRow(title: "Template") {
                Picker("", selection: Binding(
                    get: { pgTemplate ?? "" },
                    set: { pgTemplate = $0.isEmpty ? nil : $0 }
                )) {
                    Text("(default)").tag("")
                    ForEach(pgTemplates, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    func postgresDefinitionPage() -> some View {
        Section("Character Set") {
            PropertyRow(title: "Encoding") {
                Picker("", selection: $pgEncoding) {
                    ForEach(pgEncodings, id: \.self) { enc in
                        Text(enc).tag(enc)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Locale Provider") {
                Picker("", selection: $pgLocaleProvider) {
                    Text("libc").tag("libc")
                    Text("icu").tag("icu")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if pgLocaleProvider == "libc" {
                PropertyRow(title: "Collation") {
                    TextField("", text: $pgCollation, prompt: Text("e.g. en_US.UTF-8"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(title: "Character Type") {
                    TextField("", text: $pgCtype, prompt: Text("e.g. en_US.UTF-8"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                PropertyRow(title: "ICU Locale") {
                    TextField("", text: $pgIcuLocale, prompt: Text("e.g. en-US"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }

                PropertyRow(title: "ICU Rules") {
                    TextField("", text: $pgIcuRules, prompt: Text("Optional"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }
        }

        Section("Tablespace") {
            PropertyRow(title: "Tablespace") {
                Picker("", selection: $pgTablespace) {
                    ForEach(pgTablespaces, id: \.self) { ts in
                        Text(ts).tag(ts)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }

        Section("Connection") {
            PropertyRow(title: "Connection Limit", subtitle: "-1 = unlimited") {
                TextField("", value: $pgConnectionLimit, format: .number, prompt: Text("-1 for unlimited"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Is Template") {
                Toggle("", isOn: $pgIsTemplate)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            
            PropertyRow(title: "Allow Connections") {
                Toggle("", isOn: $pgAllowConnections)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }

        Section("Strategy") {
            PropertyRow(title: "Creation Strategy") {
                Picker("", selection: $pgStrategy) {
                    Text("WAL Log").tag("wal_log")
                    Text("File Copy").tag("file_copy")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }
}
