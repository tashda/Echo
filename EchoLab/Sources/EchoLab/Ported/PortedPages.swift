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
        // Written as a `RoundSpec` (see Blueprint/RoundSpec.swift).
        if page == .round14Dock {
            return LabPage.round(id: id, group: "Design Lab", title: page.rawValue, symbol: page.symbol, status: status,
                                 summary: "Icon style, dock labels and the edge under the dock.", spec: DockRound.spec)
        }
        // Playgrounds not yet rewritten as a `RoundSpec` are scaled into the round frame.
        return LabPage(
            id: id, section: .ongoing, group: "Design Lab", title: page.rawValue,
            symbol: page.symbol, status: status, summary: page.intro, ownsHeader: true,
            decision: { .legacy(page) }
        ) {
            LabRoundFrame(pageID: id, decision: .legacy(page), playSize: CGSize(width: 1180, height: 1300)) {
                DesignLabPlayground(page: page)
            }
        }
    }
}
