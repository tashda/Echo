import SwiftUI

/// Sheet for importing CSV/TSV files into a SQL Server table via Bulk Copy.
struct BulkImportSheet: View {
    @State var viewModel: BulkImportViewModel
    let onDismiss: () -> Void

    var body: some View {
        SheetLayoutCustomFooter(title: "Import Data") {
            contentArea
        } footer: {
            if let status = statusText {
                Text(status)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if viewModel.isImporting {
                Button("Cancel") { viewModel.cancelImport() }
                    .buttonStyle(.bordered)
            }
            Button("Close") { onDismiss() }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isImporting)
            if viewModel.canImport {
                Button("Import") { viewModel.startImport() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Import") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .frame(idealWidth: 720, idealHeight: 580)
        .task { await viewModel.loadTargetColumns() }
    }

    // MARK: - Content

    private var contentArea: some View {
        Form {
            fileSection
            configurationSection
            if viewModel.databaseType == .microsoftSQL {
                optionsSection
            }
            columnMappingSection
            previewSection
            progressSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - File Selection

    private var fileSection: some View {
        Section("Source File") {
            PropertyRow(title: "File") {
                HStack(spacing: SpacingTokens.xs) {
                    Text(viewModel.fileURL?.path ?? "No file selected")
                        .font(TypographyTokens.formValue)
                        .foregroundStyle(viewModel.fileURL == nil ? ColorTokens.Text.placeholder : ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("Browse") {
                        viewModel.selectFile()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !viewModel.isXLSX && !viewModel.isJSON {
                PropertyRow(title: "Delimiter") {
                    Picker("", selection: Binding(
                        get: { viewModel.delimiter },
                        set: { viewModel.reparseWithDelimiter($0) }
                    )) {
                        ForEach(CSVDelimiter.allCases) { delim in
                            Text(delim.displayName).tag(delim)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            if let error = viewModel.parseError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
                    .listRowSeparator(.hidden)
            }

            if viewModel.totalRowCount > 0 {
                Text("\(viewModel.totalRowCount) rows detected")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .listRowSeparator(.hidden)
            }
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        Section("Target") {
            if viewModel.databaseType != .sqlite {
                PropertyRow(title: "Schema") {
                    TextField("", text: $viewModel.schema, prompt: Text(viewModel.databaseType == .microsoftSQL ? "dbo" : "public"))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                }
            }

            PropertyRow(title: "Table") {
                TextField("", text: $viewModel.tableName, prompt: Text("table_name"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Batch Size") {
                TextField("", value: $viewModel.batchSize, format: .number, prompt: Text(viewModel.databaseType == .microsoftSQL ? "10000" : "1000"))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Options (SQL Server bulk load, round 25)

    private var optionsSection: some View {
        Section("Options") {
            PropertyRow(title: "Empty cells") {
                Picker("", selection: $viewModel.emptyCells) {
                    ForEach(BulkImportViewModel.EmptyCells.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            optionToggle("Keep identity values", isOn: $viewModel.identityInsert)
            optionToggle("Check constraints", isOn: $viewModel.checkConstraints)
            optionToggle("Fire triggers", isOn: $viewModel.fireTriggers)
            optionToggle("Lock the table", isOn: $viewModel.tableLock)
            Text("Locking the table is faster; other sessions wait until each batch is done.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.secondary)
                .listRowSeparator(.hidden)
        }
        .disabled(viewModel.isImporting)
    }

    private func optionToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        PropertyRow(title: title) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }


    private var statusText: String? {
        switch viewModel.phase {
        case .idle:
            return viewModel.mappedColumnCount > 0
                ? "\(viewModel.mappedColumnCount) column(s) mapped"
                : nil
        case .importing:
            return "Importing\u{2026} \(viewModel.importedRowCount.formatted()) of \(viewModel.totalRowCount.formatted()) rows"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        }
    }
}
