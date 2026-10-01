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
    var isXLSX: Bool { fileURL?.pathExtension.lowercased() == "xlsx" }
    var isJSON: Bool { fileURL?.pathExtension.lowercased() == "json" }

    // Configuration
    let databaseType: DatabaseType
    var schema: String
    var tableName: String
    /// Rows per batch. SQL Server sends each batch as one bulk load, so it starts larger.
    var batchSize: Int
    /// SQL Server: keep the file's values for identity columns.
    var identityInsert = false

    /// SQL Server: what an empty cell becomes (round 25, EC1).
    enum EmptyCells: String, CaseIterable, Identifiable {
        case null = "NULL"
        case columnDefault = "Column default"
        var id: Self { self }
    }
    var emptyCells: EmptyCells = .null
    var checkConstraints = true
    var fireTriggers = true
    var tableLock = false

    /// The server's error under a failed import's summary (SQL Server).
    var failureDetail: String?
    /// Said after an import that had to use INSERT statements (round 25, ME1).
    var completionNote: String?

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
    @ObservationIgnored private var activityHandle: OperationHandle?
    @ObservationIgnored var activityEngine: ActivityEngine?

    init(session: DatabaseSession, connectionSession: ConnectionSession, databaseType: DatabaseType, schema: String, tableName: String) {
        self.session = session
        self.connectionSession = connectionSession
        self.databaseType = databaseType
        self.schema = schema
        self.tableName = tableName
        self.batchSize = databaseType == .microsoftSQL ? 10_000 : 1_000
    }

    private var qualifiedTargetName: String {
        "\(schema.isEmpty ? "dbo" : schema).\(tableName)"
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
        panel.allowedContentTypes = [
            .commaSeparatedText, .tabSeparatedText, .plainText,
            .json,
            UTType(filenameExtension: "xlsx") ?? .data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a CSV, TSV, JSON, Excel (.xlsx), or delimited text file to import"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileURL = url
        Task { [weak self] in await self?.parseFile() }
    }

    // MARK: - Parsing

    func parseFile() async {
        guard let url = fileURL else { return }
        parseError = nil
        do {
            let result: CSVParseResult
            if isXLSX {
                result = try await XLSXFileParser.parse(url: url, previewLimit: 10)
            } else if isJSON {
                result = try await JSONFileParser.parse(url: url, previewLimit: 10)
            } else {
                result = try await CSVFileParser.parse(url: url, delimiter: delimiter, previewLimit: 10)
            }
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
        failureDetail = nil
        completionNote = nil
        importedRowCount = 0
        completedBatches = 0
        elapsedTime = 0
        activityHandle = activityEngine?.begin("Import \(tableName)", connectionSessionID: connectionSession.id)

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
            activityHandle?.cancel()
            activityHandle = nil
        }
    }

    private func executeImport() async {
        guard let url = fileURL else {
            phase = .failed(message: "No file selected")
            return
        }

        do {
            let fullResult: CSVParseResult
            if isXLSX {
                fullResult = try await XLSXFileParser.parse(url: url, previewLimit: nil)
            } else if isJSON {
                fullResult = try await JSONFileParser.parse(url: url, previewLimit: nil)
            } else {
                fullResult = try await CSVFileParser.parseAll(url: url, delimiter: delimiter)
            }

            let activeMappings = columnMappings.compactMap { mapping -> (fileIndex: Int, targetName: String)? in
                guard let target = mapping.targetColumnName else { return nil }
                return (fileIndex: mapping.id, targetName: target)
            }

            let targetColumnNames = activeMappings.map(\.targetName)
            let fileIndexes = activeMappings.map(\.fileIndex)

            let mappedRows = fullResult.rows.map { row in
                fileIndexes.map { idx in
                    guard idx < row.count else { return "" }
                    return row[idx]
                }
            }

            switch databaseType {
            case .microsoftSQL:
                try await executeMSSQLImport(rows: mappedRows, columns: targetColumnNames)
            case .postgresql, .sqlite, .mysql:
                try await executeGenericImport(rows: mappedRows, columns: targetColumnNames)
            }

            activityHandle?.succeed()
            activityHandle = nil
        } catch is CancellationError {
            timerTask?.cancel()
            // SQL Server imports run in one transaction, so a cancelled one leaves nothing behind.
            phase = .failed(message: databaseType == .microsoftSQL ? "Import cancelled. Nothing was imported." : "Import cancelled")
            activityHandle?.cancel()
            activityHandle = nil
        } catch {
            timerTask?.cancel()
            if databaseType == .microsoftSQL {
                phase = .failed(message: "Nothing was imported. \(qualifiedTargetName) is as it was.")
                failureDetail = error.localizedDescription
            } else {
                phase = .failed(message: error.localizedDescription)
            }
            activityHandle?.fail(error.localizedDescription)
            activityHandle = nil
        }
    }

    private func executeMSSQLImport(rows: [[String]], columns: [String]) async throws {
        guard let adapter = session as? SQLServerSessionAdapter else {
            throw DatabaseError.queryError("Expected SQL Server session")
        }

        let bcpRows = rows.map { row in
            let values: [SQLServerLiteralValue] = row.map { value in
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return .null }
                return .nString(trimmed)
            }
            return SQLServerBulkCopyRow(values: values)
        }

        let options = SQLServerBulkCopyOptions(
            table: tableName,
            schema: schema.isEmpty ? "dbo" : schema,
            columns: columns,
            batchSize: max(1, batchSize),
            identityInsert: identityInsert,
            checkConstraints: checkConstraints,
            fireTriggers: fireTriggers,
            keepNulls: emptyCells == .null,
            tableLock: tableLock
        )

        let batchSz = max(1, batchSize)
        let total = bcpRows.count
        let afterBatch: @Sendable (SQLServerConnection, Int) async throws -> Void = { [weak self] _, batch in
            try Task.checkCancellation()
            await MainActor.run {
                guard let self else { return }
                self.completedBatches = batch
                self.importedRowCount = min(batch * batchSz, total)
                self.activityHandle?.updateProgress(Double(self.importedRowCount) / Double(max(total, 1)))
            }
        }
        // One transaction for the whole file (round 25, FA1): a failure or a cancel leaves the
        // table as it was, so fixing the file and importing again just works.
        let summary = try await adapter.client.withConnection { connection in
            try await connection.withTransaction { connection in
                try await connection.bulkCopy(rows: bcpRows, options: options, afterBatch: afterBatch)
            }
        }

        timerTask?.cancel()
        if summary.method == .insertStatements {
            completionNote = "Imported with INSERT statements: the table has a column the bulk load cannot fill (such as geometry, sql_variant or text)."
        }
        importedRowCount = summary.totalRows
        completedBatches = summary.batchesExecuted
        elapsedTime = summary.duration
        phase = .completed(rowCount: summary.totalRows, duration: summary.duration)
    }

    private func executeGenericImport(rows: [[String]], columns: [String]) async throws {
        let effectiveSchema = databaseType == .sqlite ? nil : (schema.isEmpty ? nil : schema)
        let batchSz = max(1, batchSize)
        let total = rows.count
        let batchCount = (total + batchSz - 1) / batchSz
        totalBatches = batchCount
        let start = Date()

        for batchIndex in 0..<batchCount {
            try Task.checkCancellation()

            let batchStart = batchIndex * batchSz
            let batchEnd = min(batchStart + batchSz, total)
            let batchRows = rows[batchStart..<batchEnd]

            let sql = buildInsertSQL(
                schema: effectiveSchema,
                table: tableName,
                columns: columns,
                rows: Array(batchRows)
            )
            _ = try await session.executeUpdate(sql)

            completedBatches = batchIndex + 1
            importedRowCount = batchEnd
            activityHandle?.updateProgress(Double(batchEnd) / Double(total))
        }

        timerTask?.cancel()
        let duration = Date().timeIntervalSince(start)
        elapsedTime = duration
        phase = .completed(rowCount: total, duration: duration)
    }

    func buildInsertSQL(schema: String?, table: String, columns: [String], rows: [[String]]) -> String {
        let quotedTable: String
        if let schema {
            quotedTable = "\(quoteIdentifier(schema)).\(quoteIdentifier(table))"
        } else {
            quotedTable = quoteIdentifier(table)
        }
        let quotedColumns = columns.map(quoteIdentifier).joined(separator: ", ")

        let valueRows = rows.map { row in
            let literals = row.map { value -> String in
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return "NULL" }
                let escaped = trimmed.replacingOccurrences(of: "'", with: "''")
                return "'\(escaped)'"
            }
            return "(\(literals.joined(separator: ", ")))"
        }

        return "INSERT INTO \(quotedTable) (\(quotedColumns)) VALUES \(valueRows.joined(separator: ", "))"
    }

    private func quoteIdentifier(_ identifier: String) -> String {
        switch databaseType {
        case .microsoftSQL:
            let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        case .mysql:
            let escaped = identifier.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .postgresql, .sqlite:
            let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
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
