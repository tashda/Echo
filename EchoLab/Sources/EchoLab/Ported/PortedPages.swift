import SwiftUI

/// Registers the Design Lab pages that are still ongoing. Rounds already decided live in
/// `Decided/Library/` as frozen decisions. Round 14's verdicts are recorded and being built
/// into Echo (plan phases 11 to 17), so they start as Accepted; round 15 is still being judged.
@MainActor
enum PortedPages {
    private static let judging: [DesignLabPage] = [.round15Run, .round15Inspector, .round15Notifications]
    private static let accepted: [DesignLabPage] = [.round14Tabs, .round14Dock, .round14Connections, .round14Sense]

    static let ongoing: [LabPage] =
        judging.map { labPage($0, status: .judging) } + accepted.map { labPage($0, status: .accepted) }

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
