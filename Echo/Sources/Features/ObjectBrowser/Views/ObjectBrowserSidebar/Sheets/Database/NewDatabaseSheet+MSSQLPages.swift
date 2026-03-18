import SwiftUI
import SQLServerKit

// MARK: - MSSQL Pages

extension NewDatabaseSheet {

    @ViewBuilder
    func mssqlGeneralPage() -> some View {
        Section("Database") {
            PropertyRow(title: "Name") {
                TextField("NewDatabase", text: $databaseName)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Owner") {
                TextField("(server default)", text: $owner)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    func mssqlFilesPage() -> some View {
        Section("Data File") {
            PropertyRow(title: "Logical Name") {
                TextField("", text: $mssqlDataFileName)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Initial Size", subtitle: "MB") {
                TextField("", value: $mssqlDataFileSize, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Max Size", subtitle: "MB (0 = unlimited)") {
                TextField("", value: $mssqlDataFileMaxSize, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "File Growth", subtitle: "MB") {
                TextField("", value: $mssqlDataFileGrowth, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Log File") {
            PropertyRow(title: "Logical Name") {
                TextField("", text: $mssqlLogFileName)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Initial Size", subtitle: "MB") {
                TextField("", value: $mssqlLogFileSize, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Max Size", subtitle: "MB (0 = unlimited)") {
                TextField("", value: $mssqlLogFileMaxSize, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "File Growth", subtitle: "MB") {
                TextField("", value: $mssqlLogFileGrowth, format: .number)
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
                    TextField("(server default)", text: $mssqlCollation)
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
