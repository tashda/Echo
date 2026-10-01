import SwiftUI

/// Registers the Design Lab pages that are still ongoing. Rounds already decided live in
/// `Decided/Library/` as frozen decisions. Round 15 and the section dock are built into Echo (commits 755f8254, 2a251b61, 843675d1) and
/// wait for the owner's confirmation, so they start as In Echo; the other round 14 pages are Accepted.
@MainActor
enum PortedPages {
    private static let inEcho: [DesignLabPage] = [.round15Run, .round15Inspector, .round15Notifications, .round14Dock]
    private static let accepted: [DesignLabPage] = [.round14Tabs, .round14Connections, .round14Sense]

    static let ongoing: [LabPage] =
        inEcho.map { labPage($0, status: .inEcho) } + accepted.map { labPage($0, status: .accepted) }

    private static func labPage(_ page: DesignLabPage, status: LabStatus) -> LabPage {
        let id = "ported.\(page.id)"
        let (spec, summary): (RoundSpec, String) = switch page {
        case .round14Dock: (DockRound.spec, "Icon style, dock labels and the edge under the dock.")
        case .round14Tabs: (TabsRound.spec, "Round 9's strip on one line, and how a tool's pages open inside its tab.")
        case .round14Connections: (ConnectionsRound.spec, "Editing a connection inside Manage Connections, with the short sheet.")
        case .round14Sense: (EchoSenseRound.spec, "How the selected suggestion looks while typing and after you choose it, and its corners.")
        case .round15Run: (RunRound.spec, "Five places for Run, on one simulated query: idle, running, the result, and back.")
        case .round15Inspector: (InspectorRound.spec, "Three ways to draw the inspector column without stacked, cut-off shadows.")
        case .round15Notifications: (NotificationsRound.spec, "Where toasts start and where the notification history opens.")
        default: (RoundSpec(exhibits: []), page.intro)
        }
        return LabPage.round(id: id, group: "Design Lab", title: page.rawValue, symbol: page.symbol, status: status, summary: summary, spec: spec)
    }
}
