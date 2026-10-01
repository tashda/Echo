import Foundation

/// The Explorer's nodes laid out by the shared tree layout (EchoDesignSystem/Explorer), which
/// Echo Labs uses too.
typealias ObjectBrowserTreeLayout = ExplorerTreeLayout<ObjectBrowserNode>

extension ObjectBrowserNode: ExplorerTreeNode {
    var treeRole: ExplorerTreeRole {
        let kind: ExplorerTreeRole.Kind = switch row {
        case .topSpacer(let height): .spacer(height)
        case .server: .server
        case .pendingConnection: .pendingConnection
        case .dock(_, _, let selectedID): .dock(selectedID: selectedID)
        case .section: .section
        case .column: .column
        case .loading(_, let style): .loading(slots: style.rowSlots)
        default: .row
        }
        return ExplorerTreeRole(kind: kind, connectionID: row.connectionID, databaseName: row.databaseName,
                                extraSlotHeight: row.extraSlotHeight)
    }
}
