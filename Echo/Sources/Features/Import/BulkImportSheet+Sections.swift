import SwiftUI

extension BulkImportSheet {

    // MARK: - Column Mapping

    var columnMappingSection: some View {
        Section("Column Mapping") {
            if viewModel.fileHeaders.isEmpty {
                Text("Select a file to configure column mappings")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.placeholder)
            } else {
                ForEach(viewModel.columnMappings) { mapping in
                    HStack {
                        Text(mapping.fileColumnName)
                            .font(TypographyTokens.standard)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "arrow.right")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)

                        Picker("", selection: Binding(
                            get: { mapping.targetColumnName ?? "" },
                            set: { newValue in
                                let target = newValue.isEmpty ? nil : newValue
                                viewModel.updateMapping(fileColumnIndex: mapping.id, targetColumn: target)
                            }
                        )) {
                            Text("(skip)")
                                .tag("")
                            ForEach(viewModel.targetColumns, id: \.self) { col in
                                Text(col).tag(col)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Preview

    var previewSection: some View {
        Section("Preview") {
            if viewModel.previewRows.isEmpty {
                Text("No data to preview")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.placeholder)
            } else {
                ScrollView(.horizontal) {
                    previewTable
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var previewTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(viewModel.fileHeaders.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)
                        .frame(width: 120, alignment: .leading)
                        .padding(.horizontal, SpacingTokens.xxs)
                        .padding(.vertical, SpacingTokens.xxxs)
                }
            }
            .background(ColorTokens.Background.secondary)

            Divider()

            // Data rows
            ForEach(Array(viewModel.previewRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                        Text(value)
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.primary)
                            .frame(width: 120, alignment: .leading)
                            .padding(.horizontal, SpacingTokens.xxs)
                            .padding(.vertical, SpacingTokens.xxxs)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Progress

    var progressSection: some View {
        Group {
            if viewModel.phase != .idle {
                Section("Progress") {
                    progressContent
                }
            }
        }
    }

    @ViewBuilder
    private var progressContent: some View {
        switch viewModel.phase {
        case .idle:
            EmptyView()

        case .importing:
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                ProgressView(value: progressFraction)
                HStack {
                    Text("\(viewModel.importedRowCount) of \(viewModel.totalRowCount) rows")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                    Text("Batch \(viewModel.completedBatches)/\(viewModel.totalBatches)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

        case .completed(let count, let duration):
            Label(
                "Successfully imported \(count) rows in \(String(format: "%.2f", duration))s",
                systemImage: "checkmark.circle.fill"
            )
            .font(TypographyTokens.standard)
            .foregroundStyle(ColorTokens.Status.success)

        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Status.error)
        }
    }

    private var progressFraction: Double {
        guard viewModel.totalBatches > 0 else { return 0 }
        return Double(viewModel.completedBatches) / Double(viewModel.totalBatches)
    }
}
