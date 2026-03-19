import AppKit
import Foundation
import SQLServerKit
import UniformTypeIdentifiers

/// Tracks the current phase of a bulk import operation.
enum BulkImportPhase: Equatable {
    case idle
    case importing
    case completed(rowCount: Int, duration: TimeInterval)
    case failed(message: String)
}

/// Column mapping from a file column to a target table column.
struct ColumnMapping: Identifiable, Sendable {
    let id: Int
    let fileColumnName: String
    var targetColumnName: String?
}

/// State management for the BCP bulk import sheet.
@Observable @MainActor
final class BulkImportViewModel {
    // File state
    var fileURL: URL?
    var fileName: String { fileURL?.lastPathComponent ?? "No file selected" }
    var delimiter: CSVDelimiter = .comma
    var fileHeaders: [String] = []
    var previewRows: [[String]] = []
    var totalRowCount = 0

    // Configuration
    var schema: String
    var tableName: String
    var batchSize = 1000
    var identityInsert = false

    // Column mapping
    var columnMappings: [ColumnMapping] = []
    var targetColumns: [String] = []

    // Import state
    var phase: BulkImportPhase = .idle
    var importedRowCount = 0
    var completedBatches = 0
    var totalBatches = 0
    var elapsedTime: TimeInterval = 0

    // Error state
    var parseError: String?

    @ObservationIgnored private let session: DatabaseSession
    @ObservationIgnored private let connectionSession: ConnectionSession
    @ObservationIgnored private var importTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    init(session: DatabaseSession, connectionSession: ConnectionSession, schema: String, tableName: String) {
        self.session = session
        self.connectionSession = connectionSession
        self.schema = schema
        self.tableName = tableName
    }

    var isImporting: Bool { phase == .importing }
    var canImport: Bool {
        fileURL != nil
        && !fileHeaders.isEmpty
        && !tableName.isEmpty
        && mappedColumnCount > 0
        && phase != .importing
    }

    var mappedColumnCount: Int {
        columnMappings.filter { $0.targetColumnName != nil }.count
    }

    // MARK: - File Selection

    func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a CSV, TSV, or delimited text file to import"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileURL = url
        Task { [weak self] in await self?.parseFile() }
    }

    // MARK: - Parsing

    func parseFile() async {
        guard let url = fileURL else { return }
        parseError = nil
        do {
            let result = try await CSVFileParser.parse(
                url: url,
                delimiter: delimiter,
                previewLimit: 10
            )
            fileHeaders = result.headers
            previewRows = result.rows
            totalRowCount = result.totalRowCount
            autoMapColumns()
        } catch {
            parseError = error.localizedDescription
            fileHeaders = []
            previewRows = []
            totalRowCount = 0
            columnMappings = []
        }
    }

    func reparseWithDelimiter(_ newDelimiter: CSVDelimiter) {
        delimiter = newDelimiter
        Task { [weak self] in await self?.parseFile() }
    }

    // MARK: - Column Mapping

    func loadTargetColumns() async {
        do {
            let columns = try await session.getTableSchema(tableName, schemaName: schema.isEmpty ? nil : schema)
            targetColumns = columns.map(\.name)
            autoMapColumns()
        } catch {
            targetColumns = []
        }
    }

    private func autoMapColumns() {
        let loweredTargets = targetColumns.map { $0.lowercased() }
        columnMappings = fileHeaders.enumerated().map { index, header in
            let lowered = header.lowercased().trimmingCharacters(in: .whitespaces)
            let match = loweredTargets.firstIndex(of: lowered).map { targetColumns[$0] }
            return ColumnMapping(id: index, fileColumnName: header, targetColumnName: match)
        }
    }

    func updateMapping(fileColumnIndex: Int, targetColumn: String?) {
        guard let idx = columnMappings.firstIndex(where: { $0.id == fileColumnIndex }) else { return }
        columnMappings[idx].targetColumnName = targetColumn
    }

    // MARK: - Import Execution

    func startImport() {
        guard canImport else { return }
        phase = .importing
        importedRowCount = 0
        completedBatches = 0
        elapsedTime = 0

        let batchSz = max(1, batchSize)
        totalBatches = (totalRowCount + batchSz - 1) / batchSz

        startTimer()
        importTask = Task { [weak self] in await self?.executeImport() }
    }

    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        timerTask?.cancel()
        timerTask = nil
        if phase == .importing {
            phase = .failed(message: "Import cancelled")
        }
    }

    private func executeImport() async {
        guard let url = fileURL else {
            phase = .failed(message: "No file selected")
            return
        }

        guard let adapter = session as? SQLServerSessionAdapter else {
            phase = .failed(message: "Bulk copy is only supported for SQL Server connections")
            return
        }

        do {
            let fullResult = try await CSVFileParser.parseAll(url: url, delimiter: delimiter)

            let activeMappings = columnMappings.compactMap { mapping -> (fileIndex: Int, targetName: String)? in
                guard let target = mapping.targetColumnName else { return nil }
                return (fileIndex: mapping.id, targetName: target)
            }

            let targetColumnNames = activeMappings.map(\.targetName)
            let fileIndexes = activeMappings.map(\.fileIndex)

            let bcpRows = fullResult.rows.map { row in
                let values: [SQLServerLiteralValue] = fileIndexes.map { idx in
                    guard idx < row.count else { return .null }
                    let value = row[idx].trimmingCharacters(in: .whitespaces)
                    if value.isEmpty { return .null }
                    return .nString(value)
                }
                return SQLServerBulkCopyRow(values: values)
            }

            let options = SQLServerBulkCopyOptions(
                table: tableName,
                schema: schema.isEmpty ? "dbo" : schema,
                columns: targetColumnNames,
                batchSize: max(1, batchSize),
                identityInsert: identityInsert
            )

            let summary = try await adapter.client.bulkCopy.copy(
                rows: bcpRows,
                options: options
            )

            timerTask?.cancel()
            importedRowCount = summary.totalRows
            completedBatches = summary.batchesExecuted
            elapsedTime = summary.duration
            phase = .completed(rowCount: summary.totalRows, duration: summary.duration)
        } catch is CancellationError {
            timerTask?.cancel()
            phase = .failed(message: "Import cancelled")
        } catch {
            timerTask?.cancel()
            phase = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        let start = Date()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { break }
                self?.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
}
