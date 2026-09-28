import SwiftUI

struct TableDataView: View {
    @Bindable var viewModel: TableDataViewModel
    @State private var showingImportSheet = false

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            tableDataToolbar
            Divider()
            tableContent
            Divider()
            tableDataStatusBar
        }
        .background(ColorTokens.Background.primary)
        .tabContentFrame()
        .task {
            await viewModel.loadInitialData()
        }
        .sheet(isPresented: $showingImportSheet) {
            if let connectionSession = viewModel.connectionSession {
                BulkImportSheet(viewModel: {
                    let importViewModel = BulkImportViewModel(
                        session: viewModel.session,
                        connectionSession: connectionSession,
                        databaseType: viewModel.databaseType,
                        schema: viewModel.schemaName,
                        tableName: viewModel.tableName
                    )
                    importViewModel.activityEngine = viewModel.activityEngine
                    return importViewModel
                }()) {
                    showingImportSheet = false
                }
            }
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
                            Text("Loading more rows…")
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
        TabInitializingPlaceholder(
            icon: "tablecells",
            title: "Loading Table Data",
            subtitle: "Fetching rows…"
        )
    }

    private func errorPlaceholder(_ message: String) -> some View {
        TabContentUnavailableView("Could Not Load Table Data", systemImage: "exclamationmark.triangle") {
            Text(message)
        } actions: {
            Button("Try Again") { Task { await viewModel.loadInitialData() } }
                .buttonStyle(.bordered)
        }
    }

    private var emptyPlaceholder: some View {
        TabContentUnavailableView("No Rows", systemImage: "tablecells") {
            Text("The table does not contain any rows.")
        }
    }

    func presentImportSheet() {
        showingImportSheet = true
    }
}
