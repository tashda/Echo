import SwiftUI
import SQLServerKit

// MARK: - MSSQL Pages

extension NewDatabaseSheet {

    @ViewBuilder
    func mssqlGeneralPage() -> some View {
        Section("Database") {
            LabeledContent("Name") {
                TextField("NewDatabase", text: $databaseName)
                    .frame(width: 200)
            }

            LabeledContent("Owner") {
                TextField("(server default)", text: $owner)
                    .frame(width: 200)
            }
        }
    }

    @ViewBuilder
    func mssqlFilesPage() -> some View {
        Section("Data File") {
            LabeledContent("Logical Name") {
                TextField("", text: $mssqlDataFileName)
                    .frame(width: 200)
            }

            LabeledContent("Initial Size") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $mssqlDataFileSize, format: .number)
                        .frame(width: 60)
                    Text("MB")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            LabeledContent("Max Size") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $mssqlDataFileMaxSize, format: .number)
                        .frame(width: 60)
                    Text("MB (0 = unlimited)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            LabeledContent("File Growth") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $mssqlDataFileGrowth, format: .number)
                        .frame(width: 60)
                    Text("MB")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        Section("Log File") {
            LabeledContent("Logical Name") {
                TextField("", text: $mssqlLogFileName)
                    .frame(width: 200)
            }

            LabeledContent("Initial Size") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $mssqlLogFileSize, format: .number)
                        .frame(width: 60)
                    Text("MB")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            LabeledContent("Max Size") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $mssqlLogFileMaxSize, format: .number)
                        .frame(width: 60)
                    Text("MB (0 = unlimited)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            LabeledContent("File Growth") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $mssqlLogFileGrowth, format: .number)
                        .frame(width: 60)
                    Text("MB")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    @ViewBuilder
    func mssqlOptionsPage() -> some View {
        Section("Collation") {
            if mssqlCollations.isEmpty {
                LabeledContent("Collation") {
                    TextField("(server default)", text: $mssqlCollation)
                        .frame(width: 200)
                }
            } else {
                Picker("Collation", selection: $mssqlCollation) {
                    Text("(server default)").tag("")
                    ForEach(mssqlCollations, id: \.self) { c in
                        Text(c).tag(c)
                    }
                }
            }
        }

        Section("Containment") {
            Picker("Containment Type", selection: $mssqlContainment) {
                Text("None").tag("NONE")
                Text("Partial").tag("PARTIAL")
            }
        }
    }

}
