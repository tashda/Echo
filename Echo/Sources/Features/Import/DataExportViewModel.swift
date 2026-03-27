import Foundation
import AppKit
import UniformTypeIdentifiers

enum DataExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case text = "Text (Tab-Delimited)"

    var id: String { rawValue }

    var delimiter: String {
        switch self {
        case .csv: return ","
        case .text: return "\t"
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .text: return "tsv"
        }
    }
}

@Observable
final class DataExportViewModel {
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored let databaseType: DatabaseType
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var connectionSessionID: UUID?

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

    var showsSchemaField: Bool {
        databaseType != .sqlite
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
        !tableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !outputPath.isEmpty
            && !isExporting
    }

    var generatedSQL: String {
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
    }

    @MainActor
    func selectOutputFile() {
        let panel = NSSavePanel()
        panel.title = "Export Data"
        panel.nameFieldStringValue = "\(tableName).\(format.fileExtension)"
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
            let result = try await session.simpleQuery(generatedSQL)
            let delim = customDelimiter.isEmpty ? format.delimiter : customDelimiter

            var lines: [String] = []

            if includeHeader {
                let headerLine = result.columns.map { escapeCSVField($0.name, delimiter: delim) }
                lines.append(headerLine.joined(separator: delim))
            }

            for row in result.rows {
                let fields = row.map { value -> String in
                    guard let value else { return "" }
                    return escapeCSVField(value, delimiter: delim)
                }
                lines.append(fields.joined(separator: delim))
            }

            let content = lines.joined(separator: "\n")
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

    private static func defaultSchema(for databaseType: DatabaseType) -> String {
        switch databaseType {
        case .postgresql: return "public"
        case .microsoftSQL: return "dbo"
        case .mysql: return ""
        case .sqlite: return ""
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

    private func escapeCSVField(_ value: String, delimiter: String) -> String {
        let needsQuoting = value.contains(delimiter) || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
