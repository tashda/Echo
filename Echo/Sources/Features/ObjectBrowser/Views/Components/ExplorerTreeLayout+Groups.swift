import CoreGraphics
import Foundation

/// The rows grouped for pinning (TC1): a server with a dock pins its name and dock while its
/// rows scroll under them, until the next server pushes them away. Everything else is a group
/// without a header.
extension ExplorerTreeLayout {
    struct Group: Identifiable {
        let id: String
        let header: [Row]
        let rows: [Row]
    }

    var groups: [Group] {
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
            switch row.node.row {
            case .server:
                close()
                if index + 1 < rows.count, case .dock = rows[index + 1].node.row {
                    header = [row, rows[index + 1]]
                    index += 2
                    continue
                }
                body.append(row)
            case .pendingConnection, .topSpacer:
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

    /// The row at the top of the view and its server's connection, for returning to a dock section.
    func topRow(atOffset offset: CGFloat, baseRowHeight: CGFloat) -> (id: String, connectionID: UUID?)? {
        guard let index = rowIndex(at: offset + baseRowHeight / 2) else { return nil }
        return (rows[index].id, topVisibleContext(atOffset: offset, baseRowHeight: baseRowHeight)?.connectionID)
    }
}
