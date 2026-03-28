import SwiftUI

extension TablePropertiesView {

    @ViewBuilder
    var storagePage: some View {
        if viewModel.isPostgres {
            postgresStoragePage
        } else if viewModel.isMySQL {
            mysqlStoragePage
        } else if viewModel.isMSSQL {
            mssqlStoragePage
        }
    }

    // MARK: - PostgreSQL

    @ViewBuilder
    private var postgresStoragePage: some View {
        Section("Storage Parameters") {
            PropertyRow(title: "Fill Factor", subtitle: "Default 100") {
                TextField("", text: $viewModel.pgFillfactor, prompt: Text("e.g. 90"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "TOAST Tuple Target") {
                TextField("", text: $viewModel.pgToastTupleTarget, prompt: Text("e.g. 128"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "Parallel Workers") {
                TextField("", text: $viewModel.pgParallelWorkers, prompt: Text("e.g. 2"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Autovacuum") {
            PropertyRow(title: "Enabled") {
                Toggle("", isOn: $viewModel.pgAutovacuumEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }

        Section("Tablespace") {
            PropertyRow(title: "Tablespace") {
                TextField("", text: $viewModel.pgEditableTablespace, prompt: Text("e.g. pg_default"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        if let options = viewModel.pgOptions, !options.isEmpty {
            Section("Current Storage Options") {
                ForEach(options, id: \.self) { option in
                    let parts = option.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        PropertyRow(title: String(parts[0])) {
                            Text(String(parts[1]))
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - MSSQL

    @ViewBuilder
    private var mssqlStoragePage: some View {
        Section("Compression") {
            PropertyRow(title: "Data Compression") {
                Text(viewModel.mssqlDataCompression ?? "NONE")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Filegroups") {
            PropertyRow(title: "Filegroup") {
                Text(viewModel.mssqlFilegroup ?? "PRIMARY")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            if let textFg = viewModel.mssqlTextFilegroup {
                PropertyRow(title: "Text Filegroup") {
                    Text(textFg)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            if let fsFg = viewModel.mssqlFilestreamFilegroup {
                PropertyRow(title: "Filestream Filegroup") {
                    Text(fsFg)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }

        if viewModel.mssqlIsPartitioned {
            Section("Partitioning") {
                PropertyRow(title: "Table Is Partitioned") {
                    flagIcon(true)
                }
                if let scheme = viewModel.mssqlPartitionScheme {
                    PropertyRow(title: "Partition Scheme") {
                        Text(scheme)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                if let column = viewModel.mssqlPartitionColumn {
                    PropertyRow(title: "Partition Column") {
                        Text(column)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                if let count = viewModel.mssqlPartitionCount {
                    PropertyRow(title: "Number of Partitions") {
                        Text(String(count))
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            }
        }
    }

    // MARK: - MySQL

    @ViewBuilder
    private var mysqlStoragePage: some View {
        Section("Storage Options") {
            PropertyRow(title: "Engine") {
                TextField("", text: $viewModel.mysqlEngine, prompt: Text("e.g. InnoDB"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "Row Format") {
                TextField("", text: $viewModel.mysqlRowFormat, prompt: Text("e.g. Dynamic"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "Auto Increment") {
                TextField("", text: $viewModel.mysqlAutoIncrement, prompt: Text("e.g. 1000"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Encoding") {
            PropertyRow(title: "Character Set") {
                TextField("", text: $viewModel.mysqlCharacterSet, prompt: Text("e.g. utf8mb4"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            PropertyRow(title: "Collation") {
                TextField("", text: $viewModel.mysqlCollation, prompt: Text("e.g. utf8mb4_0900_ai_ci"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }

        Section("Comment") {
            TextField("", text: $viewModel.mysqlComment, prompt: Text("Add a table comment"))
                .textFieldStyle(.roundedBorder)
        }
    }
}
