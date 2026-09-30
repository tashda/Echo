import SwiftUI

/// Registers the pages copied from the in-app Design Lab. Pages still being judged are
/// Ongoing; rounds already decided sit under Decided until each is frozen into a
/// `LabDecision` with its options as live code (see PORTING.md).
@MainActor
enum PortedPages {
    private static let ongoingPages: [DesignLabPage] = [
        .round15Run, .round15Inspector, .round15Notifications,
        .round14Tabs, .round14Dock, .round14Connections, .round14Sense,
        .round13,
    ]

    static let ongoing: [LabPage] = ongoingPages.map { page in
        labPage(page, section: .ongoing, group: "Ported from Design Lab", status: .judging)
    }

    static let decided: [LabPage] = DesignLabPage.allCases
        .filter { !ongoingPages.contains($0) }
        .map { labPage($0, section: .decided, group: "Ported, not yet frozen", status: .decided) }

    private static func labPage(_ page: DesignLabPage, section: LabSection, group: String, status: LabStatus) -> LabPage {
        LabPage(
            id: "ported.\(page.id)",
            section: section,
            group: group,
            title: page.rawValue,
            symbol: page.symbol,
            status: status,
            summary: "Copied from the in-app Design Lab."
        ) { DesignLabPageView(page: page) }
    }
}
