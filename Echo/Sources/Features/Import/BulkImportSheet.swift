import SwiftUI

/// Sheet for importing CSV/TSV files into a SQL Server table via Bulk Copy.
struct BulkImportSheet: View {
    @State var viewModel: BulkImportViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
            Divider()
            footerBar
        }
        .frame(minWidth: 680, minHeight: 520)
        .frame(idealWidth: 720, idealHeight: 580)
        .task { await viewModel.loadTargetColumns() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label("Import Data", systemImage: "square.and.arrow.down")
                .font(TypographyTokens.prominent.weight(.semibold))
            Spacer()
            Text(viewModel.fileName)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    // MARK: - Content

    private var contentArea: some View {
        Form {
            fileSection
            configurationSection
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
                    
                    Button("Browse\u{2026}") {
                        viewModel.selectFile()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

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
            PropertyRow(title: "Schema") {
                TextField("", text: $viewModel.schema)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }
            
            PropertyRow(title: "Table") {
                TextField("", text: $viewModel.tableName)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Batch Size") {
                TextField("", value: $viewModel.batchSize, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
            }

            PropertyRow(title: "Identity Insert") {
                Toggle("", isOn: $viewModel.identityInsert)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
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
            Button("Import") { viewModel.startImport() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canImport)
        }
        .padding(SpacingTokens.md)
    }

    private var statusText: String? {
        switch viewModel.phase {
        case .idle:
            return viewModel.mappedColumnCount > 0
                ? "\(viewModel.mappedColumnCount) column(s) mapped"
                : nil
        case .importing:
            let elapsed = String(format: "%.1f", viewModel.elapsedTime)
            return "Importing\u{2026} \(viewModel.importedRowCount) rows (\(viewModel.completedBatches)/\(viewModel.totalBatches) batches) \(elapsed)s"
        case .completed(let count, let duration):
            let dur = String(format: "%.2f", duration)
            return "Completed: \(count) rows imported in \(dur)s"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}
