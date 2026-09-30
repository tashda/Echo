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
        LabPage(
            id: "ported.\(page.id)",
            section: .ongoing,
            group: "Design Lab",
            title: page.rawValue,
            symbol: page.symbol,
            status: status,
            summary: "Copied from the in-app Design Lab."
        ) { DesignLabPageView(page: page) }
    }
}
