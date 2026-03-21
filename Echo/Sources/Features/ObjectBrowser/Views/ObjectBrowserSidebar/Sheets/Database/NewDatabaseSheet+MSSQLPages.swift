import SwiftUI
import SQLServerKit

// MARK: - MSSQL Pages

extension NewDatabaseSheet {

    @ViewBuilder
    func mssqlGeneralPage() -> some View {
        Section("Database") {
            PropertyRow(title: "Name") {
                TextField("", text: $databaseName, prompt: Text("NewDatabase"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Owner") {
                TextField("", text: $owner, prompt: Text("sa"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    func mssqlFilesPage() -> some View {
        Section("Data File") {
            PropertyRow(title: "Logical Name") {
                TextField("", text: $mssqlDataFileName, prompt: Text("database_data"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Initial Size", subtitle: "MB") {
                TextField("", value: $mssqlDataFileSize, format: .number, prompt: Text("100"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Max Size", subtitle: "MB (0 = unlimited)") {
                TextField("", value: $mssqlDataFileMaxSize, format: .number, prompt: Text("-1 for unlimited"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "File Growth", subtitle: "MB") {
                TextField("", value: $mssqlDataFileGrowth, format: .number, prompt: Text("10"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Log File") {
            PropertyRow(title: "Logical Name") {
                TextField("", text: $mssqlLogFileName, prompt: Text("database_log"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Initial Size", subtitle: "MB") {
                TextField("", value: $mssqlLogFileSize, format: .number, prompt: Text("50"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Max Size", subtitle: "MB (0 = unlimited)") {
                TextField("", value: $mssqlLogFileMaxSize, format: .number, prompt: Text("-1 for unlimited"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "File Growth", subtitle: "MB") {
                TextField("", value: $mssqlLogFileGrowth, format: .number, prompt: Text("10"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    func mssqlOptionsPage() -> some View {
        Section("Collation") {
            if mssqlCollations.isEmpty {
                PropertyRow(title: "Collation") {
                    TextField("", text: $mssqlCollation, prompt: Text("SQL_Latin1_General_CP1_CI_AS"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                PropertyRow(title: "Collation") {
                    Picker("", selection: $mssqlCollation) {
                        Text("(server default)").tag("")
                        ForEach(mssqlCollations, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }

        Section("Containment") {
            PropertyRow(title: "Containment Type") {
                Picker("", selection: $mssqlContainment) {
                    Text("None").tag("NONE")
                    Text("Partial").tag("PARTIAL")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

}
