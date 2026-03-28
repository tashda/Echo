import SwiftUI

struct TableDataView: View {
    @Bindable var viewModel: TableDataViewModel

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            tableDataToolbar
            Divider()
            tableContent
            Divider()
            tableDataStatusBar
        }
        .background(ColorTokens.Background.primary)
        .task {
            await viewModel.loadInitialData()
        }
    }

    @ViewBuilder
    private var tableContent: some View {
        if viewModel.isLoading {
            loadingPlaceholder
        } else if let error = viewModel.errorMessage, viewModel.rows.isEmpty {
            errorPlaceholder(error)
        } else if viewModel.rows.isEmpty {
            emptyPlaceholder
        } else {
            tableDataGrid
        }
    }

    @ViewBuilder
    private var tableDataGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: SpacingTokens.none, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(viewModel.rows.enumerated()), id: \.offset) { rowIndex, row in
                        TableDataRowView(
                            rowIndex: rowIndex,
                            row: row,
                            columns: viewModel.columns,
                            isEditMode: viewModel.isEditMode,
                            pendingEdits: viewModel.pendingEdits,
                            onEditCell: { colIndex, newValue in
                                viewModel.editCell(row: rowIndex, column: colIndex, newValue: newValue)
                            },
                            onSetCellNull: { colIndex in
                                viewModel.setCellToNull(row: rowIndex, column: colIndex)
                            },
                            onTransformCell: { colIndex, transform in
                                viewModel.transformCellText(row: rowIndex, column: colIndex, using: transform)
                            },
                            onLoadCellFromFile: { colIndex, url in
                                viewModel.loadCellValue(row: rowIndex, column: colIndex, from: url)
                            },
                            onSetValueMode: { colIndex, mode in
                                viewModel.setValueMode(row: rowIndex, column: colIndex, to: mode)
                            },
                            onDeleteRow: {
                                Task { await viewModel.deleteRow(at: rowIndex) }
                            },
                            canEdit: viewModel.canEdit
                        )
                        .onAppear {
                            if rowIndex == viewModel.rows.count - 20 {
                                Task { await viewModel.loadNextPage() }
                            }
                        }
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading more rows...")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(SpacingTokens.sm)
                    }
                } header: {
                    TableDataHeaderView(
                        columns: viewModel.columns,
                        isEditMode: viewModel.isEditMode
                    )
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: SpacingTokens.sm) {
            ProgressView()
            Text("Loading data...")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorPlaceholder(_ message: String) -> some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Status.error)
            Text(message)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "tablecells")
                .font(TypographyTokens.hero)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No rows found")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
