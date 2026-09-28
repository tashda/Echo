import AppKit
import Observation

/// Shares state between the Explorer tree and the server rail, which live side by side
/// in the sidebar but are owned by different views.
@Observable @MainActor
final class ServerRailBridge {
    /// Connection whose rows are at the top of the Explorer's visible area. Drives the rail's
    /// highlight so it follows the user while scrolling.
    var topVisibleConnectionID: UUID?

    /// Context menus are built by the Explorer, which owns the sheets and state they act on.
    @ObservationIgnored var sessionMenu: ((ConnectionSession) -> NSMenu)?
    @ObservationIgnored var pendingMenu: ((PendingConnection) -> NSMenu)?
}
