import SwiftUI
import CryptoKit

struct ClipboardHistoryArchive: Codable {
    let version: Int
    var entries: [ClipboardHistoryEntry]
}

struct ClipboardHistoryUsageBreakdown: Equatable {
    var queryBytes: Int
    var gridBytes: Int
    var totalBytes: Int { queryBytes + gridBytes }
    init(queryBytes: Int = 0, gridBytes: Int = 0) {
        self.queryBytes = queryBytes; self.gridBytes = gridBytes
    }
}

struct ClipboardHistoryEntry: Identifiable, Equatable, Codable {
    enum Source: Equatable {
        case queryEditor
        case resultGrid(includeHeaders: Bool)

        var iconName: String {
            switch self {
            case .queryEditor: return "doc.text"
            case .resultGrid(true): return "tablecells.fill"
            case .resultGrid(false): return "tablecells"
            }
        }

        var tint: Color {
            switch self {
            case .queryEditor: return .accentColor
            case .resultGrid(true): return Color.orange
            case .resultGrid(false): return Color.blue
            }
        }

        var caption: String {
            switch self {
            case .queryEditor: return "Query Editor"
            case .resultGrid(true): return "Grid • Headers"
            case .resultGrid(false): return "Grid"
            }
        }

        var usageCategory: UsageCategory {
            switch self {
            case .queryEditor: return .query
            case .resultGrid: return .grid
            }
        }
    }

    enum UsageCategory { case query, grid }

    struct Metadata: Equatable, Codable {
        var serverName: String?
        var databaseName: String?
        var objectName: String?
        var connectionColorHex: String?

        var hasDetails: Bool {
            let hasServer = !(serverName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasDatabase = !(databaseName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasObject = !(objectName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            return hasServer || hasDatabase || hasObject
        }

        init(serverName: String? = nil, databaseName: String? = nil, objectName: String? = nil, connectionColorHex: String? = nil) {
            self.serverName = serverName; self.databaseName = databaseName; self.objectName = objectName; self.connectionColorHex = connectionColorHex
        }
        
        static let empty = Metadata()
    }

    let id: UUID
    var source: Source
    var content: String
    var timestamp: Date
    var metadata: Metadata

    init(id: UUID = UUID(), source: Source, content: String, timestamp: Date = Date(), metadata: Metadata = Metadata()) {
        self.id = id; self.source = source; self.content = content; self.timestamp = timestamp; self.metadata = metadata
    }

    var previewText: String {
        let trimmed = content.replacingOccurrences(of: "\n", with: " ⏎ ")
        if trimmed.count <= 140 { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 140)
        return String(trimmed[..<index]) + "…"
    }

    var timestampDisplay: String {
        timestamp.formatted(.dateTime.year().month(.abbreviated).day().hour(.twoDigits(amPM: .omitted)).minute())
    }

    var formattedSize: String {
        let bytes = estimatedSizeInBytes
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }

    var estimatedSizeInBytes: Int {
        var total = content.lengthOfBytes(using: .utf8)
        if let s = metadata.serverName { total += s.lengthOfBytes(using: .utf8) }
        if let d = metadata.databaseName { total += d.lengthOfBytes(using: .utf8) }
        if let o = metadata.objectName { total += o.lengthOfBytes(using: .utf8) }
        if let c = metadata.connectionColorHex { total += c.lengthOfBytes(using: .utf8) }
        return total + 128
    }
}

extension ClipboardHistoryEntry.Source: Codable {
    private enum CodingKeys: String, CodingKey { case kind, includeHeaders }
    private enum Kind: String, Codable { case queryEditor, resultGrid }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .queryEditor: self = .queryEditor
        case .resultGrid: self = .resultGrid(includeHeaders: try container.decode(Bool.self, forKey: .includeHeaders))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .queryEditor: try container.encode(Kind.queryEditor, forKey: .kind); try container.encode(false, forKey: .includeHeaders)
        case .resultGrid(let h): try container.encode(Kind.resultGrid, forKey: .kind); try container.encode(h, forKey: .includeHeaders)
        }
    }
}
