/// Every area, in sidebar order, and which area each round belongs to.
@MainActor
enum LabAreas {
    static let all: [LabArea] = registry.map { $0.withDerivedSpec(code: specCodes[$0.id] ?? $0.id.uppercased()) }

    /// Codes for the IDs of areas whose spec is read from their As built page.
    private static let specCodes = [
        "foundations": "FND", "explorer-tree": "TREE", "window": "WIN", "editor": "EDT", "footer-results": "FTR",
        "inspector": "INS", "connections": "CON", "echosense": "SNS", "notifications": "NTF",
    ]

    private static let registry: [LabArea] = [
        FoundationsArea.area,
        ExplorerTreeArea.area,
        TabsArea.area,
        ToolTabsArea.area,
        WindowArea.area,
        EditorArea.area,
        FooterResultsArea.area,
        InspectorArea.area,
        ConnectionsArea.area,
        EchoSenseArea.area,
        NotificationsArea.area,
    ]

    private static func pending(_ id: String, _ title: String, _ symbol: String, _ summary: String) -> LabArea {
        LabArea(id: id, title: title, symbol: symbol, summary: summary, asBuilt: .pending(title))
    }

    /// Sidebar groups, in order. Foundations stands alone.
    static let groups: [(title: String?, ids: [String])] = [
        (nil, ["foundations"]),
        ("Window", ["window", "tabs"]),
        ("Content", ["explorer-tree", "tool-tabs", "editor", "footer-results", "inspector"]),
        ("Overlays", ["echosense", "notifications", "connections"]),
    ]

    static func groupTitle(ofArea id: String) -> String? { groups.first { $0.ids.contains(id) }?.title }

    static func area(id: String?) -> LabArea? { all.first { $0.id == id } }

    /// Round pages (`LabPage.id`) and the area they belong to.
    static let roundAreas: [String: String] = [
        "decided.round9-footer-scroller-tabs": "window",
        "decided.round10-footer-and-switcher": "footer-results",
        "decided.round11-tab-bar": "tabs",
        "decided.round12-two-line-tabs": "tabs",
        "decided.round13-tab-directions": "tabs",
        "decided.tree-card-s4-quiet": "explorer-tree",
        "decided.window-canvas-and-cards": "window",
        "decided.rail-servers": "window",
        "decided.tree-sticky-header": "explorer-tree",
        "decided.results-grid": "footer-results",
        "decided.toasts-and-notifications": "notifications",
        "decided.inspector-column": "inspector",
        "ported.Round 15 · Run": "editor",
        "ported.Round 15 · inspector": "inspector",
        "ported.Round 15 · notifications": "notifications",
        "ongoing.notification-history-r17": "notifications",
        "ongoing.server-card-r16": "explorer-tree",
        "ported.Round 14 · tab bar and pages": "tabs",
        "ported.Round 14 · section dock": "explorer-tree",
        "ported.Round 14 · connections": "connections",
        "ported.Round 14 · EchoSense selection": "echosense",
        "ongoing.notification-toast-r18": "notifications",
        "ongoing.section-dock-switching-r19": "explorer-tree",
        "ongoing.section-dock-capsule-r19": "explorer-tree",
        "ongoing.section-dock-sections-r19": "explorer-tree",
        "ongoing.run-button-look-r20": "editor",
        "ongoing.run-button-running-r20": "editor",
        "ongoing.pg-transaction-state-r21": "footer-results",
        "ongoing.pg-open-transaction-guard-r21": "tabs",
        "ongoing.pg-connection-lost-r21": "notifications",
        "ongoing.pg-cancel-r21": "editor",
        "ongoing.pg-script-results-r21": "footer-results",
        "ongoing.pg-error-location-r21": "editor",
        "ongoing.pg-value-display-r21": "footer-results",
        "ongoing.pg-timeouts-r21": "connections",
        "ongoing.mssql-values-r22": "footer-results",
        "ongoing.mssql-errors-r22": "editor",
        "ongoing.mssql-sessions-r22": "editor",
        "ongoing.mssql-encryption-r22": "connections",
        "ongoing.pg-kerberos-signin-r23": "connections",
        "ongoing.pg-client-key-password-r23": "connections",
        "ongoing.pg-failover-hosts-r23": "connections",
        "ongoing.run-into-running-r24": "editor",
        "ongoing.mssql-import-r25": "explorer-tree",
        "ongoing.content-during-slide-r26": "window",
        "ongoing.results-scrollers-r27": "footer-results",
        "ongoing.editor-text-r28": "editor",
        "ongoing.editor-gutter-r28": "editor",
        "ongoing.editor-caret-line-r28": "editor",
        "ongoing.editor-statement-r28": "editor",
        "ongoing.editor-marks-r28": "editor",
        "ongoing.editor-errors-r28": "editor",
        "ongoing.editor-run-note-r28": "editor",
        "ongoing.editor-zoom-r28": "editor",
        "ongoing.editor-find-typing-r28": "editor",
        "ongoing.editor-empty-r28": "editor",
        "ongoing.editor-settings-r28": "editor",
        "ongoing.mssql-always-encrypted-r29": "footer-results",
        // ROUND-AREAS (Scripts/new-round.py adds new rounds above this line)
    ]

    /// The area a page belongs to: its As built id, the explicit map above, or, for a new round
    /// nobody has mapped yet, the area whose title matches the page's `group`. Nil only when
    /// neither applies; the Inbox still lists such pages so nothing goes missing.
    static func areaID(ofPage id: String) -> String? {
        if id.hasPrefix("asbuilt.") { return String(id.dropFirst("asbuilt.".count)) }
        if let mapped = roundAreas[id] { return mapped }
        guard let group = LabRegistry.page(id: id)?.group else { return nil }
        return all.first { $0.title == group }?.id
    }

    /// Rounds of an area, not including its As built page.
    static func rounds(in area: LabArea) -> [LabPage] {
        LabRegistry.pages.filter { !$0.id.hasPrefix("asbuilt.") && areaID(ofPage: $0.id) == area.id }
    }
}
