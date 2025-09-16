import SwiftUI

struct QueryView: View {
    let connection: SavedConnection
    let session: DatabaseSession

    @EnvironmentObject private var appState: AppState
    @State private var sql: String = "SELECT now();"
    @State private var results: QueryResultSet?
    @State private var errorMessage: String?
    @State private var queryStartTime: Date?

    var body: some View {
        VStack(spacing: 0) {
            // Query input section
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Query").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)

                            Spacer()

                            if !appState.queryHistory.isEmpty {
                                Menu {
                                    ForEach(appState.queryHistory.prefix(10)) {
                                        item in
                                        Button(action: {
                                            sql = item.query
                                        }) {
                                            VStack(alignment: .leading) {
                                                Text(item.query.prefix(50) + (item.query.count > 50 ? "...": "")).lineLimit(1)
                                                Text(item.formattedTimestamp).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }

                                    Divider()

                                    Button("Clear History") {
                                        appState.clearQueryHistory()
                                    }
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath").font(.caption).foregroundStyle(.secondary)
                                }.menuStyle(.borderlessButton)
                            }
                        }

                        TextEditor(text: $sql).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).frame(minHeight: 60, maxHeight: 120)
                    }

                    VStack(spacing: 8) {
                        Button {
                            Task {
                                await runQuery()
                            }
                        } label: {
                            Label("Run Query", systemImage: "play.fill").font(.subheadline).fontWeight(.medium)
                        }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.return, modifiers: [.command]).disabled(appState.isQueryRunning || sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if appState.isQueryRunning {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
            }.padding(16).background(.regularMaterial, in: Rectangle())

            Divider()

            // Results section
            VStack(spacing: 0) {
                if let results = results {
                    EnhancedResultsTable(resultSet: results)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundStyle(.orange)

                        VStack(spacing: 8) {
                            Text("Query Error").font(.headline)

                            Text(errorMessage).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).textSelection(.enabled)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(32)
                } else {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "tablecells")
                    } description: {
                        Text("Run a SQL query to see results here")
                    } actions: {
                        Button("Run Example Query") {
                            sql = "SELECT NOW() as current_time, VERSION() as db_version;"
                            Task {
                                await runQuery()
                            }
                        }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }.padding().onAppear {
            // Initialize with app state's current query if available
            if !appState.currentQuery.isEmpty {
                sql = appState.currentQuery
            }
        }.onChange(of: sql) {
            _, newValue in
            // Save current query to app state
            appState.currentQuery = newValue
        }
    }

    private func runQuery() async {
        appState.isQueryRunning = true
        errorMessage = nil
        results = nil
        queryStartTime = Date()

        defer {
            appState.isQueryRunning = false
        }

        do {
            let queryResults = try await session.simpleQuery(sql)
            results = queryResults

            // Calculate query duration and add to history
            let duration = queryStartTime?.timeIntervalSinceNow.magnitude
            appState.addToQueryHistory(
                sql,
                resultCount: queryResults.rows.count,
                duration: duration
            )

        } catch let dbError as DatabaseError {
            errorMessage = dbError.localizedDescription
            appState.showError(dbError)
        } catch {
            errorMessage = error.localizedDescription
            let dbError = DatabaseError.from(error)
            appState.showError(dbError)
        }
    }
}

private struct EnhancedResultsTable: View {
    let resultSet: QueryResultSet
    @State private var sortCriteria: SortCriteria?
    @State private var filters: [String: String] = [:]
    @State private var selectedRows: Set<Int> = []
    @State private var showingFilters = false

    private var sortedAndFilteredRows: [Int] {
        var indices = Array(0 ..< resultSet.rows.count)

        // Apply filters
        if !filters.isEmpty {
            indices = indices.filter {
                rowIndex in
                let row = resultSet.rows[rowIndex]
                for (columnName, filterValue) in filters {
                    guard !filterValue.isEmpty,
                    let columnIndex = resultSet.columns.firstIndex(where: {
                        $0.name == columnName
                    }) else {
                        continue
                    }

                    let cellValue = row[columnIndex] ?? ""
                    if !cellValue.localizedCaseInsensitiveContains(filterValue) {
                        return false
                    }
                }
                return true
            }
        }

        // Apply sorting
        if let sort = sortCriteria,
        let columnIndex = resultSet.columns.firstIndex(where: {
            $0.name == sort.column
        }) {
            indices.sort {
                index1, index2 in
                let value1 = resultSet.rows[index1][columnIndex] ?? ""
                let value2 = resultSet.rows[index2][columnIndex] ?? ""

                // Try numeric comparison first
                if let num1 = Double(value1), let num2 = Double(value2) {
                    return sort.ascending ? num1 < num2: num1 > num2
                }

                // Fall back to string comparison
                let comparison = value1.localizedCaseInsensitiveCompare(value2)
                return sort.ascending ? comparison == .orderedAscending: comparison == .orderedDescending
            }
        }

        return indices
    }

    private func toggleSort(for column: ColumnInfo) {
        if sortCriteria?.column == column.name {
            sortCriteria = SortCriteria(column: column.name, ascending: !(sortCriteria?.ascending ?? false))
        } else {
            sortCriteria = SortCriteria(column: column.name, ascending: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tablecells").font(.caption).foregroundStyle(.secondary)
                    Text("\(sortedAndFilteredRows.count) of \(resultSet.rows.count) rows").font(.caption).foregroundStyle(.secondary)

                    if selectedRows.count > 0 {
                        Text("• \(selectedRows.count) selected").font(.caption).foregroundStyle(.blue)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    // Filter toggle
                    Button(action: {
                        showingFilters.toggle()
                    }) {
                        Image(systemName: showingFilters ? "line.3.horizontal.decrease.circle.fill": "line.3.horizontal.decrease.circle").foregroundStyle(showingFilters || !filters.isEmpty ? .blue: .secondary)
                    }.buttonStyle(.borderless).font(.caption).help("Toggle filters")

                    if !filters.isEmpty {
                        Button(action: {
                            filters.removeAll()
                        }) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
                        }.buttonStyle(.borderless).font(.caption).help("Clear all filters")
                    }

                    Button(action: {
                        // Export functionality
                        exportResults()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }.buttonStyle(.borderless).font(.caption).help("Export")

                    Button(action: {
                        // Refresh would re-run the query
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }.buttonStyle(.borderless).font(.caption).disabled(true).help("Refresh")
                }
            }.padding(.horizontal, 16).padding(.vertical, 10).background(.regularMaterial)

            Divider()

            // Filter row
            if showingFilters {
                HStack(spacing: 0) {
                    ForEach(Array(resultSet.columns.enumerated()), id: \.offset) {
                        index, column in
                        TextField("Filter", text: Binding(
                            get: {
                                filters[column.name] ?? ""
                            },
                            set: {
                                if $0.isEmpty {
                                    filters.removeValue(forKey: column.name)
                                } else {
                                    filters[column.name] = $0
                                }
                            }
                        )).textFieldStyle(.plain).font(.system(.caption2, design: .monospaced)).padding(.horizontal, 8).padding(.vertical, 6).background(.quaternary, in: RoundedRectangle(cornerRadius: 4)).frame(minWidth: 120, maxWidth: .infinity).padding(.horizontal, 8).background(.regularMaterial.opacity(0.5)).overlay(
                            Rectangle().fill(.separator).frame(width: 1).opacity(index < resultSet.columns.count - 1 ? 0.3: 0),
                            alignment: .trailing
                        )
                    }
                }.padding(.vertical, 8)

                Divider()
            }

            // Data table - same implementation as before...
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    // Header row with sorting
                    HStack(spacing: 0) {
                        ForEach(Array(resultSet.columns.enumerated()), id: \.offset) {
                            index, column in
                            Button(action: {
                                toggleSort(for: column)
                            }) {
                                HStack(spacing: 6) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(column.name).font(.system(.caption, design: .default)).fontWeight(.semibold).foregroundStyle(.primary).lineLimit(1)

                                            if column.isPrimaryKey {
                                                Image(systemName: "key.fill").font(.caption2).foregroundStyle(.yellow)
                                            }
                                        }

                                        Text(column.dataType.uppercased()).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if sortCriteria?.column == column.name {
                                        Image(systemName: sortCriteria?.ascending == true ? "chevron.up": "chevron.down").font(.caption2).foregroundStyle(.blue)
                                    }
                                }
                            }.buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 8).frame(minWidth: 120, maxWidth: .infinity, alignment: .leading).background(.thickMaterial).overlay(
                                Rectangle().fill(.separator).frame(width: 1).opacity(index < resultSet.columns.count - 1 ? 0.5: 0),
                                alignment: .trailing
                            )
                        }
                    }

                    // Data rows
                    ForEach(Array(sortedAndFilteredRows.enumerated()), id: \.element) {
                        displayIndex, rowIndex in
                        HStack(spacing: 0) {
                            ForEach(Array(resultSet.rows[rowIndex].enumerated()), id: \.offset) {
                                columnIndex, cell in
                                let isSelected = selectedRows.contains(rowIndex)

                                HStack(spacing: 8) {
                                    if columnIndex == 0 {
                                        Circle().fill(isSelected ? .blue: .clear).stroke(isSelected ? .blue: .secondary, lineWidth: 1).frame(width: 8, height: 8)
                                    }

                                    Group {
                                        if let cellValue = cell, !cellValue.isEmpty {
                                            Text(cellValue).font(.system(.callout, design: .monospaced)).foregroundStyle(.primary)
                                        } else {
                                            Text("NULL").font(.system(.callout, design: .monospaced)).foregroundStyle(.tertiary).italic()
                                        }
                                    }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(.horizontal, 12).padding(.vertical, 8).frame(minWidth: 120, maxWidth: .infinity, alignment: .leading).background(
                                    Group {
                                        if isSelected {
                                            Color.accentColor.opacity(0.15)
                                        } else if displayIndex % 2 == 1 {
                                            Color.primary.opacity(0.04)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                ).overlay(
                                    Rectangle().fill(.separator).frame(width: 1).opacity(columnIndex < resultSet.rows[rowIndex].count - 1 ? 0.2: 0),
                                    alignment: .trailing
                                ).overlay(
                                    Rectangle().fill(.separator).frame(height: 1).opacity(displayIndex < sortedAndFilteredRows.count - 1 ? 0.1: 0),
                                    alignment: .bottom
                                ).contextMenu {
                                    Button("Copy Cell") {
                                        if let value = cell {
                                            NSPasteboard.general.setString(value, forType: .string)
                                        }
                                    }

                                    Button("Filter by Value") {
                                        if let value = cell {
                                            filters[resultSet.columns[columnIndex].name] = value
                                            showingFilters = true
                                        }
                                    }
                                }
                            }
                        }.contentShape(Rectangle()).onTapGesture {
                            if selectedRows.contains(rowIndex) {
                                selectedRows.remove(rowIndex)
                            } else {
                                selectedRows.insert(rowIndex)
                            }
                        }
                    }
                }.background(.background).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)).overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.separator.opacity(0.5), lineWidth: 1)
                ).padding(12)
            }.background(.regularMaterial.opacity(0.3))
        }.background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func exportResults() {
        // Simple CSV export
        var csvContent = resultSet.columns.map {
            $0.name
        }.joined(separator: ",") + "\n"

        for row in resultSet.rows {
            let csvRow = row.map {
                cell in
                let value = cell ?? "NULL"
                // Simple CSV escaping
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return value
            }.joined(separator: ",")
            csvContent += csvRow + "\n"
        }

        NSPasteboard.general.setString(csvContent, forType: .string)
    }
}