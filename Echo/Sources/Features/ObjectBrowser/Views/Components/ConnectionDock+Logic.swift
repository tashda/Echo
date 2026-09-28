import SwiftUI

extension ConnectionDock {
    internal var isEmpty: Bool {
        entries.isEmpty
    }

    internal var connectionCount: Int {
        entries.count
    }

    internal var canExpandDock: Bool {
        connectionCount > LayoutTokens.ConnectionDock.collapsedItemLimit
    }

    internal var visibleEntries: [ConnectionDockEntry] {
        let allEntries = entries
        let indices = ConnectionDockVisibilityPolicy.visibleIndices(
            connectionIDs: allEntries.map(\.connectionID),
            selectedConnectionID: selectedConnectionID,
            showsAllConnections: showsAllConnections
        )
        return indices.map { allEntries[$0] }
    }

    private var entries: [ConnectionDockEntry] {
        sessions.map(ConnectionDockEntry.session)
            + pendingConnections.map(ConnectionDockEntry.pending)
    }

    internal func displayName(for connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }

    internal func statusColor(for state: ConnectionState) -> Color? {
        switch state {
        case .connected:
            return ColorTokens.Status.success
        case .connecting, .testing:
            return ColorTokens.Status.warning
        case .disconnected:
            return ColorTokens.Text.tertiary
        case .error:
            return ColorTokens.Status.error
        }
    }

    internal func isConnecting(_ state: ConnectionState) -> Bool {
        switch state {
        case .connecting, .testing: return true
        default: return false
        }
    }

    internal func stateDescription(for state: ConnectionState) -> String {
        switch state {
        case .connected: return "Connected"
        case .connecting, .testing: return "Connecting"
        case .disconnected: return "Disconnected"
        case .error: return "Connection error"
        }
    }

    internal func pendingHelpText(_ pending: PendingConnection) -> String {
        switch pending.phase {
        case .connecting:
            return "Connecting to \(pending.connection.host)"
        case .failed(let message):
            return message
        }
    }

    internal func pendingStateDescription(_ pending: PendingConnection) -> String {
        switch pending.phase {
        case .connecting: return "Connecting"
        case .failed: return "Connection failed. Activate to retry."
        }
    }

    internal func pendingStatusColor(_ pending: PendingConnection) -> Color? {
        switch pending.phase {
        case .connecting: return ColorTokens.Status.warning
        case .failed: return ColorTokens.Status.error
        }
    }

    internal func pendingIsConnecting(_ pending: PendingConnection) -> Bool {
        if case .connecting = pending.phase {
            return true
        }
        return false
    }
}
