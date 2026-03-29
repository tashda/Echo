import Foundation
import Observation
import SQLServerKit
import Logging

@Observable @MainActor
final class QuickImportViewModel {
    var fileURL: URL?
    var schema = "dbo"
    var tableName = ""
    var firstRowHasHeaders = true
    var delimiter: CSVDelimiter = .comma
    
    var sampleRows: [[String]] = []
    var headers: [String] = []
    var inferences: [SQLServerColumnInference] = []
    
    var isLoading = false
    var isImporting = false
    var progress: Double = 0
    var statusMessage = ""
    
    private let session: DatabaseSession
    private let logger = Logger(label: "QuickImportViewModel")
    
    init(session: DatabaseSession) {
        self.session = session
    }
    
    func parseFile() {
        guard let url = fileURL else { return }
        isLoading = true
        
        Task {
            do {
                let result = try await CSVFileParser.parse(url: url, delimiter: delimiter, previewLimit: 100)
                
                if firstRowHasHeaders {
                    headers = result.headers
                    sampleRows = result.rows
                } else {
                    headers = result.headers.indices.map { "Column\($0 + 1)" }
                    sampleRows = [result.headers] + result.rows
                }
                
                if let bulkClient = session.bulkCopy {
                    inferences = bulkClient.inferSchema(headers: headers, sampleRows: sampleRows)
                }
                
                if tableName.isEmpty {
                    tableName = url.deletingPathExtension().lastPathComponent
                        .replacingOccurrences(of: " ", with: "_")
                        .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                }
                
                isLoading = false
            } catch {
                logger.error("Failed to parse file: \(error)")
                isLoading = false
            }
        }
    }
    
    func startImport() {
        guard let url = fileURL else { return }
        isImporting = true
        progress = 0
        statusMessage = "Creating table..."
        
        Task {
            do {
                guard let bulkClient = session.bulkCopy else {
                    throw NSError(domain: "Echo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bulk copy not supported"])
                }
                
                // 1. Create table
                let createSql = bulkClient.generateCreateTableSQL(schema: schema, table: tableName, columns: inferences)
                _ = try await session.executeUpdate(createSql)
                
                // 2. Import data
                statusMessage = "Reading file..."
                let result = try await CSVFileParser.parseAll(url: url, delimiter: delimiter)
                let dataRows = firstRowHasHeaders ? result.rows : ([result.headers] + result.rows)
                
                statusMessage = "Importing \(dataRows.count) rows..."
                
                // Convert string rows to SQLServerBulkCopyRow
                let bulkRows = dataRows.map { strings in
                    SQLServerBulkCopyRow(values: strings.map { .string($0) })
                }
                
                let options = SQLServerBulkCopyOptions(
                    table: tableName,
                    schema: schema,
                    columns: inferences.map { $0.name }
                )
                
                _ = try await bulkClient.copy(rows: bulkRows, options: options) { _, batchNum in
                    await MainActor.run {
                        self.statusMessage = "Imported batch \(batchNum)..."
                    }
                }
                
                statusMessage = "Import complete."
                isImporting = false
            } catch {
                logger.error("Import failed: \(error)")
                statusMessage = "Error: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }
}
