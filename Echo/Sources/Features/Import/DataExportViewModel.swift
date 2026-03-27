import Foundation
import AppKit
import UniformTypeIdentifiers

enum DataExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case text = "Text (Tab-Delimited)"
    case json = "JSON"
    case sqlInsert = "SQL INSERT"

    var id: String { rawValue }

    var delimiter: String {
        switch self {
        case .csv: return ","
        case .text: return "\t"
        case .json, .sqlInsert: return ","
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .text: return "tsv"
        case .json: return "json"
        case .sqlInsert: return "sql"
        }
    }
}

@Observable
final class DataExportViewModel: Identifiable {
    enum Source {
        case table
        case resultSet(QueryResultSet, suggestedFileName: String, tableName: String?)
    }

    @ObservationIgnored let session: DatabaseSession?
    @ObservationIgnored let databaseType: DatabaseType
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var connectionSessionID: UUID?
    @ObservationIgnored let source: Source
    let id = UUID()

    var schema: String
    var tableName: String
    var format: DataExportFormat = .csv
    var customDelimiter: String = ""
    var includeHeader: Bool = true
    var encoding: String = ""
    var outputPath: String = ""
    var outputURL: URL?
    var isExporting = false
    var statusMessage: String?
    var isError = false

    var isResultSetExport: Bool {
        if case .resultSet = source {
            return true
        }
        return false
    }

    var supportsDelimitedOptions: Bool {
        format == .csv || format == .text
    }

    var showsSchemaField: Bool {
        !isResultSetExport && databaseType != .sqlite
    }

    var schemaPlaceholder: String {
        switch databaseType {
        case .postgresql: return "e.g. public"
        case .microsoftSQL: return "e.g. dbo"
        case .mysql: return "e.g. mydb"
        case .sqlite: return ""
        }
    }

    var canExport: Bool {
        !outputPath.isEmpty && !isExporting && {
            switch source {
            case .table:
                return !tableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .resultSet:
                return true
            }
        }()
    }

    var generatedSQL: String {
        guard !isResultSetExport else { return "" }
        let table = tableName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !table.isEmpty else { return "" }

        let quotedTable = quoteIdentifier(table)
        if schema.isEmpty || databaseType == .sqlite {
            return "SELECT * FROM \(quotedTable)"
        }
        let quotedSchema = quoteIdentifier(schema)
        return "SELECT * FROM \(quotedSchema).\(quotedTable)"
    }

    init(session: DatabaseSession, databaseType: DatabaseType, schema: String? = nil, tableName: String = "") {
        self.session = session
        self.databaseType = databaseType
        self.schema = schema ?? Self.defaultSchema(for: databaseType)
        self.tableName = tableName
        self.source = .table
    }

    init(databaseType: DatabaseType, resultSet: QueryResultSet, suggestedFileName: String = "results", tableName: String? = nil) {
        self.session = nil
        self.databaseType = databaseType
        self.schema = ""
        self.tableName = ""
        self.source = .resultSet(resultSet, suggestedFileName: suggestedFileName, tableName: tableName)
    }

    @MainActor
    func selectOutputFile() {
        let panel = NSSavePanel()
        panel.title = "Export Data"
        panel.nameFieldStringValue = "\(suggestedFileName).\(format.fileExtension)"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            outputURL = url
            outputPath = url.path
        }
    }

    func executeExport() async {
        guard canExport, let url = outputURL else { return }
        isExporting = true
        isError = false
        statusMessage = "Exporting\u{2026}"

        let label = schema.isEmpty ? tableName : "\(schema).\(tableName)"
        let handle = activityEngine?.begin("Export \(label)", connectionSessionID: connectionSessionID)

        do {
            let result: QueryResultSet
            let insertTableName: String?

            switch source {
            case .table:
                guard let session else {
                    throw NSError(domain: "DataExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "No session is available for table export"])
                }
                result = try await session.simpleQuery(generatedSQL)
                insertTableName = tableName.trimmingCharacters(in: .whitespacesAndNewlines)
            case let .resultSet(exportResult, _, tableName):
                result = exportResult
                insertTableName = tableName
            }

            let content = formattedContent(for: result, tableName: insertTableName)
            let enc: String.Encoding = encoding.lowercased() == "latin1" ? .isoLatin1 : .utf8
            guard let data = content.data(using: enc) else {
                throw NSError(domain: "DataExport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode output"])
            }
            try data.write(to: url)

            let rowCount = result.rows.count
            statusMessage = "Exported \(rowCount) rows to \(url.lastPathComponent)"
            handle?.succeed()
        } catch {
            statusMessage = error.localizedDescription
            isError = true
            handle?.fail(error.localizedDescription)
        }

        isExporting = false
    }

    // MARK: - Private

    private var suggestedFileName: String {
        switch source {
        case .table:
            return tableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "export" : tableName
        case let .resultSet(_, suggestedFileName, _):
            return suggestedFileName
        }
    }

    private static func defaultSchema(for databaseType: DatabaseType) -> String {
        switch databaseType {
        case .postgresql: return "public"
        case .microsoftSQL: return "dbo"
        case .mysql: return ""
        case .sqlite: return ""
        }
    }

    private func formattedContent(for result: QueryResultSet, tableName: String?) -> String {
        let headers = result.columns.map(\.name)
        let rows = result.rows

        switch format {
        case .csv:
            let delimiter = customDelimiter.isEmpty ? format.delimiter : customDelimiter
            return formatDelimited(headers: headers, rows: rows, delimiter: delimiter, includeHeader: includeHeader)
        case .text:
            let delimiter = customDelimiter.isEmpty ? format.delimiter : customDelimiter
            return formatDelimited(headers: headers, rows: rows, delimiter: delimiter, includeHeader: includeHeader)
        case .json:
            return ResultTableExportFormatter.format(.json, headers: headers, rows: rows)
        case .sqlInsert:
            return ResultTableExportFormatter.formatSQLInsert(
                tableName: tableName ?? "table_name",
                headers: headers,
                rows: rows,
                databaseType: databaseType
            )
        }
    }

    private func quoteIdentifier(_ identifier: String) -> String {
        switch databaseType {
        case .mysql:
            return "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
        case .microsoftSQL:
            return "[\(identifier.replacingOccurrences(of: "]", with: "]]"))]"
        case .postgresql, .sqlite:
            return "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
    }

    private func formatDelimited(headers: [String], rows: [[String?]], delimiter: String, includeHeader: Bool) -> String {
        var lines: [String] = []

        if includeHeader {
            lines.append(headers.map { escapeCSVField($0, delimiter: delimiter) }.joined(separator: delimiter))
        }

        for row in rows {
            let fields = row.map { value -> String in
                guard let value else { return "" }
                return escapeCSVField(value, delimiter: delimiter)
            }
            lines.append(fields.joined(separator: delimiter))
        }

        return lines.joined(separator: "\n")
    }

    private func escapeCSVField(_ value: String, delimiter: String) -> String {
        let needsQuoting = value.contains(delimiter) || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
