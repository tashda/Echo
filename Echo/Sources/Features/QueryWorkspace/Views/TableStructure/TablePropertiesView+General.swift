import SwiftUI

extension TablePropertiesView {

    @ViewBuilder
    var generalPage: some View {
        if viewModel.isPostgres {
            postgresGeneralPage
        } else if viewModel.isMySQL {
            mysqlGeneralPage
        } else if viewModel.isMSSQL {
            mssqlGeneralPage
        }
    }

    // MARK: - PostgreSQL

    @ViewBuilder
    private var postgresGeneralPage: some View {
        Section("Identity") {
            PropertyRow(title: "Schema") {
                Text(viewModel.schemaName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Name") {
                Text(viewModel.tableName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Owner") {
                Text(viewModel.pgOwner)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            if viewModel.pgOid > 0 {
                PropertyRow(title: "OID") {
                    Text(String(viewModel.pgOid))
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let tablespace = viewModel.pgTablespace {
                PropertyRow(title: "Tablespace") {
                    Text(tablespace)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        Section("Size") {
            PropertyRow(title: "Total Size") {
                Text(EchoFormatters.bytes(Int(viewModel.totalSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Table Size") {
                Text(EchoFormatters.bytes(Int(viewModel.tableSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Indexes Size") {
                Text(EchoFormatters.bytes(Int(viewModel.indexesSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Estimated Rows") {
                Text(EchoFormatters.compactNumber(viewModel.rowCount))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Properties") {
            PropertyRow(title: "Has Indexes") {
                flagIcon(viewModel.pgHasIndexes)
            }
            PropertyRow(title: "Has Triggers") {
                flagIcon(viewModel.pgHasTriggers)
            }
            PropertyRow(title: "Row Level Security") {
                flagIcon(viewModel.pgRowSecurity)
            }
            PropertyRow(title: "Is Partitioned") {
                flagIcon(viewModel.pgIsPartitioned)
            }
        }

        if let desc = viewModel.pgDescription, !desc.isEmpty {
            Section("Description") {
                Text(desc)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    // MARK: - MSSQL

    @ViewBuilder
    private var mssqlGeneralPage: some View {
        Section("Identity") {
            PropertyRow(title: "Schema") {
                Text(viewModel.schemaName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Name") {
                Text(viewModel.tableName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            if let created = viewModel.mssqlCreatedDate {
                PropertyRow(title: "Created") {
                    Text(created)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let modified = viewModel.mssqlModifiedDate {
                PropertyRow(title: "Last Modified") {
                    Text(modified)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        Section("Size") {
            PropertyRow(title: "Row Count") {
                Text(EchoFormatters.compactNumber(viewModel.rowCount))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Data Space") {
                Text(EchoFormatters.bytes(Int(viewModel.tableSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Index Space") {
                Text(EchoFormatters.bytes(Int(viewModel.indexesSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Total Reserved") {
                Text(EchoFormatters.bytes(Int(viewModel.totalSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Options") {
            PropertyRow(title: "Lock Escalation") {
                Text(viewModel.mssqlLockEscalation ?? "TABLE")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "ANSI NULLs") {
                flagIcon(viewModel.mssqlUsesAnsiNulls)
            }
            PropertyRow(title: "System Object") {
                flagIcon(viewModel.mssqlIsSystemObject)
            }
            PropertyRow(title: "Is Replicated") {
                flagIcon(viewModel.mssqlIsReplicated)
            }
            if viewModel.mssqlIsMemoryOptimized {
                PropertyRow(title: "Memory Optimized") {
                    flagIcon(true)
                }
                if let durability = viewModel.mssqlDurability {
                    PropertyRow(title: "Durability") {
                        Text(durability)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
            if viewModel.mssqlIsSystemVersioned {
                PropertyRow(title: "System-Versioned") {
                    flagIcon(true)
                }
            }
        }
    }

    // MARK: - MySQL

    @ViewBuilder
    private var mysqlGeneralPage: some View {
        Section("Identity") {
            PropertyRow(title: "Schema") {
                Text(viewModel.schemaName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Name") {
                Text(viewModel.tableName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Engine") {
                Text(viewModel.mysqlEngine.isEmpty ? "InnoDB" : viewModel.mysqlEngine)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Size") {
            PropertyRow(title: "Estimated Rows") {
                Text(EchoFormatters.compactNumber(viewModel.rowCount))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Data Size") {
                Text(EchoFormatters.bytes(Int(viewModel.tableSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Index Size") {
                Text(EchoFormatters.bytes(Int(viewModel.indexesSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Total Size") {
                Text(EchoFormatters.bytes(Int(viewModel.totalSizeBytes)))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Options") {
            PropertyRow(title: "Character Set") {
                Text(viewModel.mysqlCharacterSet.isEmpty ? "Default" : viewModel.mysqlCharacterSet)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Collation") {
                Text(viewModel.mysqlCollation.isEmpty ? "Default" : viewModel.mysqlCollation)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Row Format") {
                Text(viewModel.mysqlRowFormat.isEmpty ? "Default" : viewModel.mysqlRowFormat)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Auto Increment") {
                Text(viewModel.mysqlAutoIncrement.isEmpty ? "Not Set" : viewModel.mysqlAutoIncrement)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        if !viewModel.mysqlComment.isEmpty {
            Section("Comment") {
                Text(viewModel.mysqlComment)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    // MARK: - Shared

    func flagIcon(_ value: Bool) -> some View {
        Image(systemName: value ? "checkmark" : "minus")
            .foregroundStyle(value ? ColorTokens.Status.success : ColorTokens.Text.tertiary)
    }
}
