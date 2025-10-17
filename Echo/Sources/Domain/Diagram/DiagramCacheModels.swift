import Foundation
import CoreGraphics
import CryptoKit

/// Identifies a cached diagram by project, connection, and object metadata.
struct DiagramCacheKey: Hashable, Codable, Sendable {
    let projectID: UUID
    let connectionID: UUID
    let schema: String
    let table: String
    /// Future-proof hook for supporting multiple render layouts.
    let layoutID: String

    init(
        projectID: UUID,
        connectionID: UUID,
        schema: String,
        table: String,
        layoutID: String = DiagramLayoutSnapshot.defaultLayoutIdentifier
    ) {
        self.projectID = projectID
        self.connectionID = connectionID
        self.schema = schema
        self.table = table
        self.layoutID = layoutID
    }

    var canonicalFilename: String {
        let identifier = "\(schema.lowercased()).\(table.lowercased())"
        let sanitized = identifier.replacingOccurrences(of: "[^a-z0-9._-]", with: "-", options: .regularExpression)
        let fingerprintInput = [
            projectID.uuidString.lowercased(),
            connectionID.uuidString.lowercased(),
            schema.lowercased(),
            table.lowercased(),
            layoutID.lowercased()
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(fingerprintInput.utf8))
        let prefix = digest.hexEncodedString(prefixLength: 8)
        return "\(prefix)-\(sanitized)-\(layoutID)"
    }
}

/// Captures structural metadata required to rebuild a diagram.
struct DiagramStructureSnapshot: Codable, Sendable {
    struct TableEntry: Codable, Sendable {
        let schema: String
        let name: String
        let details: TableStructureDetails
    }

    let baseTable: TableEntry
    let relatedTables: [TableEntry]
}

/// Persists node layout and per-column anchoring so cached diagrams render instantly.
struct DiagramLayoutSnapshot: Codable, Sendable {
    struct NodePosition: Codable, Sendable {
        let nodeID: String
        let x: Double
        let y: Double
    }

    static let defaultLayoutIdentifier = "primary"

    let layoutID: String
    let nodePositions: [NodePosition]

    init(layoutID: String = Self.defaultLayoutIdentifier, nodePositions: [NodePosition]) {
        self.layoutID = layoutID
        self.nodePositions = nodePositions
    }
}

/// Full payload stored in the encrypted cache on disk.
struct DiagramCachePayload: Codable, Sendable {
    let key: DiagramCacheKey
    let checksum: String
    let generatedAt: Date
    let structure: DiagramStructureSnapshot
    let layout: DiagramLayoutSnapshot
    /// Optional textual status shown during instant loads.
    let loadingSummary: String?

    init(
        key: DiagramCacheKey,
        checksum: String,
        generatedAt: Date = Date(),
        structure: DiagramStructureSnapshot,
        layout: DiagramLayoutSnapshot,
        loadingSummary: String? = nil
    ) {
        self.key = key
        self.checksum = checksum
        self.generatedAt = generatedAt
        self.structure = structure
        self.layout = layout
        self.loadingSummary = loadingSummary
    }
}

/// User-facing prefetch modes exposed in settings.
enum DiagramPrefetchMode: String, CaseIterable, Codable, Sendable {
    case off
    case recentlyOpened
    case full

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .recentlyOpened: return "Recent tables"
        case .full: return "All tables"
        }
    }
}

/// Background refresh cadence for checksum validation.
enum DiagramRefreshCadence: String, CaseIterable, Codable, Sendable {
    case never
    case daily
    case weekly

    var displayName: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

/// Utility helper for generating structural checksums.
enum DiagramChecksum {
    static func makeChecksum(
        base: TableStructureDetails,
        related: [DiagramStructureSnapshot.TableEntry]
    ) -> String {
        var accumulator = SHA256()
        update(&accumulator, table: base)
        related.sorted(by: { lhs, rhs in
            if lhs.schema.caseInsensitiveCompare(rhs.schema) == .orderedSame {
                return lhs.name.lowercased() < rhs.name.lowercased()
            }
            return lhs.schema.lowercased() < rhs.schema.lowercased()
        }).forEach { update(&accumulator, table: $0.details) }
        let digest = accumulator.finalize()
        return digest.hexEncodedString(prefixLength: 32)
    }

    private static func update(_ hasher: inout SHA256, table: TableStructureDetails) {
        hasher.update(data: Data((table.primaryKey?.name ?? "").lowercased().utf8))
        table.columns.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }).forEach { column in
            hasher.update(data: Data(column.name.lowercased().utf8))
            hasher.update(data: Data(column.dataType.lowercased().utf8))
            hasher.update(data: Data(String(column.isNullable).utf8))
            hasher.update(data: Data((column.defaultValue ?? "").lowercased().utf8))
            hasher.update(data: Data((column.generatedExpression ?? "").lowercased().utf8))
        }
        table.foreignKeys.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }).forEach { fk in
            hasher.update(data: Data(fk.name.lowercased().utf8))
            fk.columns.sorted(by: { $0.lowercased() < $1.lowercased() }).forEach {
                hasher.update(data: Data($0.lowercased().utf8))
            }
            hasher.update(data: Data(fk.referencedSchema.lowercased().utf8))
            hasher.update(data: Data(fk.referencedTable.lowercased().utf8))
            fk.referencedColumns.sorted(by: { $0.lowercased() < $1.lowercased() }).forEach {
                hasher.update(data: Data($0.lowercased().utf8))
            }
            hasher.update(data: Data((fk.onUpdate ?? "").lowercased().utf8))
            hasher.update(data: Data((fk.onDelete ?? "").lowercased().utf8))
        }
    }
}

private extension Sequence where Element == UInt8 {
    func hexEncodedString(prefixLength: Int? = nil) -> String {
        var result = String()
        if let prefixLength {
            result.reserveCapacity(prefixLength)
        }
        var processedCharacters = 0
        for byte in self {
            if let prefixLength, processedCharacters >= prefixLength {
                break
            }
            let chunk = String(format: "%02X", byte)
            if let prefixLength, processedCharacters + 2 > prefixLength {
                let remaining = prefixLength - processedCharacters
                result.append(chunk.prefix(remaining))
                processedCharacters = prefixLength
                break
            } else {
                result.append(chunk)
                processedCharacters += 2
            }
        }
        return result
    }
}
