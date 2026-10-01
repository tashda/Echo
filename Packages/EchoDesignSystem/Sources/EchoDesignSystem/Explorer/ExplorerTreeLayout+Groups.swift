import CoreGraphics
import Foundation

/// The rows grouped for pinning (TC1): a server with a dock pins its name and dock while its
/// rows scroll under them, until the next server pushes them away. A closed server is a header
/// with no rows. Everything else is a group without a header.
extension ExplorerTreeLayout {
    public struct Group: Identifiable {
        public let id: String
        public let header: [Row]
        public let rows: [Row]
    }

    public var groups: [Group] {
        var groups: [Group] = []
        var header: [Row] = []
        var body: [Row] = []
        func close() {
            guard !header.isEmpty || !body.isEmpty else { return }
            groups.append(Group(id: (header.first ?? body.first)?.id ?? UUID().uuidString, header: header, rows: body))
            header = []
            body = []
        }
        var index = 0
        while index < rows.count {
            let row = rows[index]
            switch row.role.kind {
            case .server:
                close()
                if index + 1 < rows.count, case .dock = rows[index + 1].role.kind {
                    header = [row, rows[index + 1]]
                    index += 2
                    continue
                }
                // A closed server is a header of its own, as when open, so its name stays the
                // same view while the card folds and opens (round 30.2).
                if index + 1 == rows.count || rows[index + 1].role.startsCard || rows[index + 1].role.isSpacer {
                    header = [row]
                    index += 1
                    continue
                }
                body.append(row)
            case .pendingConnection, .spacer:
                close()
                body.append(row)
                close()
            default:
                body.append(row)
            }
            index += 1
        }
        close()
        return groups
    }

    /// Each docked server's current section, by connection.
    public var dockSelections: [UUID: String] {
        var selections: [UUID: String] = [:]
        for row in rows {
            if case .dock(let selectedID) = row.role.kind, let connectionID = row.role.connectionID {
                selections[connectionID] = selectedID
            }
        }
        return selections
    }

    /// Where a server's card starts: the top of its name row.
    public func serverTop(_ connectionID: UUID) -> CGFloat? {
        rows.first { $0.role.kind == .server && $0.role.connectionID == connectionID }?.minY
    }

    /// A veil for every switching server's card body.
    public func veils(switching: Set<UUID>, opaque: Set<UUID>) -> [ExplorerTreeVeil] {
        guard !switching.isEmpty else { return [] }
        return groups.compactMap { group in
            guard let serverRow = group.header.first, let connectionID = serverRow.role.connectionID,
                  switching.contains(connectionID),
                  let card = cards.first(where: { $0.id == serverRow.id })
            else { return nil }
            let headerHeight = group.header.reduce(0) { $0 + $1.height }
            return .init(id: connectionID, bodyTop: serverRow.minY + headerHeight, bodyBottom: card.minY + card.height,
                         headerHeight: headerHeight, isOpaque: opaque.contains(connectionID))
        }
    }
}
