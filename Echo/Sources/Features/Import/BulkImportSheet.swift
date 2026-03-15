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
            HStack {
                Text(viewModel.fileURL?.path ?? "No file selected")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(viewModel.fileURL == nil ? ColorTokens.Text.placeholder : ColorTokens.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Browse\u{2026}") {
                    viewModel.selectFile()
                }
            }

            Picker("Delimiter", selection: Binding(
                get: { viewModel.delimiter },
                set: { viewModel.reparseWithDelimiter($0) }
            )) {
                ForEach(CSVDelimiter.allCases) { delim in
                    Text(delim.displayName).tag(delim)
                }
            }
            .pickerStyle(.menu)

            if let error = viewModel.parseError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Status.error)
            }

            if viewModel.totalRowCount > 0 {
                Text("\(viewModel.totalRowCount) rows detected")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        Section("Target") {
            TextField("Schema", text: $viewModel.schema)
            TextField("Table", text: $viewModel.tableName)

            HStack {
                Text("Batch Size")
                Spacer()
                TextField("", value: $viewModel.batchSize, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }

            Toggle("Identity Insert", isOn: $viewModel.identityInsert)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if let status = statusText {
                Text(status)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if viewModel.isImporting {
                Button("Cancel") { viewModel.cancelImport() }
            }
            Button("Close") { onDismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isImporting)
            Button("Import") { viewModel.startImport() }
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
