/// Every design round, newest first: what it asked, what was decided, and its pages.
@MainActor
enum LabRounds {
    struct Info: Identifiable {
        let id: String
        /// "Round 14".
        let label: String
        let title: String
        let date: String
        /// What the round asked, in plain words.
        let asked: String
        /// What was decided (or where it stands).
        let outcome: String
        /// The round's pages (`LabPage.id`).
        let pageIDs: [String]
        /// A round can cover several topics; each is a line with its outcome.
        var topics: [(title: String, outcome: String)] = []
    }

    static let all: [Info] = [
        // ROUND-INFO (Scripts/new-round.py adds new rounds below this line, newest first)
        Info(id: "r22", label: "Round 22", title: "SQL Server: encryption settings", date: "30 Sep 2026",
             asked: "What do Optional, Mandatory and Strict mean now, which is the default, and how does the sheet explain them?",
             outcome: "Being judged.",
             pageIDs: ["ongoing.mssql-encryption-r22"]),
        Info(id: "r22", label: "Round 22", title: "SQL Server: cancel, timeouts and lost connections", date: "30 Sep 2026",
             asked: "Cancel no longer throws the query tab's session away; what changes for cancel, the 45-second limit and a dropped connection?",
             outcome: "Being judged.",
             pageIDs: ["ongoing.mssql-sessions-r22"]),
        Info(id: "r22", label: "Round 22", title: "SQL Server: errors and messages", date: "30 Sep 2026",
             asked: "How should SQL Server errors show their number, severity, state and line, and what does a commit with an unknown outcome say?",
             outcome: "Being judged.",
             pageIDs: ["ongoing.mssql-errors-r22"]),
        Info(id: "r22", label: "Round 22", title: "SQL Server: values in the grid", date: "30 Sep 2026",
             asked: "Values after row 200 of a SQL Server result are garbled, and dates, offsets and money lose digits; how should they read?",
             outcome: "Being judged.",
             pageIDs: ["ongoing.mssql-values-r22"]),
        Info(id: "r21", label: "Round 21", title: "PostgreSQL: sessions, scripts and results", date: "30 Sep 2026",
             asked: "Everything Echo can now do with PostgreSQL that needs a look first: eight pages. Transaction state in a tab, closing or switching with an open transaction, a lost connection, cancelling on the server, script results, where an error is, how PostgreSQL values read in the grid, and statement timeouts.",
             outcome: "Being judged.",
             pageIDs: ["ongoing.pg-transaction-state-r21", "ongoing.pg-open-transaction-guard-r21", "ongoing.pg-connection-lost-r21", "ongoing.pg-cancel-r21", "ongoing.pg-script-results-r21", "ongoing.pg-error-location-r21", "ongoing.pg-value-display-r21", "ongoing.pg-timeouts-r21"]),
        Info(id: "r20", label: "Round 20", title: "Run button", date: "30 Sep 2026",
             asked: "Everything the Run button can be, now that it sits in its own toolbar group: two pages, how it looks at rest (form, icon, colour, selection, hover, unavailable, other modes) and how it moves (running look, a delay for quick queries, timer, stop icon, motion, the change into running, the result). Changes EDT-4.1 to EDT-4.5.",
             outcome: "Being judged.",
             pageIDs: ["ongoing.run-button-look-r20", "ongoing.run-button-running-r20"]),
        Info(id: "r19", label: "Round 19", title: "Section dock", date: "30 Sep 2026",
             asked: "Three pages on the dock as built in round 16: how a card switches sections (and why the card above moves), how the capsule looks, and how many sections a dock holds and what happens to the rest. Changes TREE-1.2 and TREE-3.1 to TREE-3.7.",
             outcome: "Being judged.",
             pageIDs: ["ongoing.section-dock-switching-r19", "ongoing.section-dock-capsule-r19", "ongoing.section-dock-sections-r19"]),
        Info(id: "r18", label: "Round 18", title: "Notification toast", date: "30 Sep 2026",
             asked: "Everything about the toast itself: its layout, actions, dismissing, material, how it arrives, how several stack, and how long it stays.",
             outcome: "Title and detail, small buttons, swipe right to dismiss; glass, drop from the top, a list of three and 3 s kept. Built into Echo; waiting for your check in the running app.",
             pageIDs: ["ongoing.notification-toast-r18"]),
        Info(id: "r17", label: "Round 17", title: "Notification history", date: "30 Sep 2026",
             asked: "How the notification history looks in the inspector's column, and how a notification opens to its whole, selectable message.",
             outcome: "Accepted: D · Compact cards by time, fading in; the count beside the title with one ⋯ menu (H3); small buttons (A2). Built into Echo; waiting for your check in the running app.",
             pageIDs: ["ongoing.notification-history-r17"]),
        Info(id: "r16", label: "Round 16", title: "Server card", date: "30 Sep 2026",
             asked: "Your bugs and feedback on the section dock as built: header and dock styles, the edge under the pinned header, switching, loading, counts, selection, dock customising and PostgreSQL's sections.",
             outcome: "First look: H5 glass capsule, version under the name, blur rows, crossfade, quiet skeleton, counts always, symmetric selection; customising and PostgreSQL's sections kept. Being judged again: H5 as Xcode's navigator icons with rows blurred under the glass, blur rows modelled on the system edge (with a reference), what stays pinned, and five spinner options for the initial load.",
             pageIDs: ["ongoing.server-card-r16"]),
        Info(id: "r15", label: "Round 15", title: "Run, inspector and notifications", date: "30 Sep 2026",
             asked: "Five places for the Run button, three looks for the inspector column, and where toasts and the history live.",
             outcome: "Run is a plain ▶ in its own capsule. The inspector is one card with grouped boxes. Toasts sit at the top right of the first card; the history opens in the inspector's column. Built into Echo (commit 755f8254), waiting for your confirmation.",
             pageIDs: ["ported.Round 15 · Run", "ported.Round 15 · inspector", "ported.Round 15 · notifications"]),
        Info(id: "r14", label: "Round 14", title: "Design board answers", date: "30 Sep 2026",
             asked: "The design board's remaining Maybes drawn on the real tokens, in four topics: tab bar and how a tool's pages open, the section dock and icon style, the connection sheet, and EchoSense selection and corners.",
             outcome: "Answered on 30 Sep; parts are built (the dock and icons), the rest is accepted and waiting to be built.",
             pageIDs: ["ported.Round 14 · tab bar and pages", "ported.Round 14 · section dock", "ported.Round 14 · connections", "ported.Round 14 · EchoSense selection"],
             topics: [
                ("Tab bar and pages", "Round 9's strip on one line; a tool's pages unfold inside its tab (ST2). N1, N1R and N7, and the drawer, tab group, page menu and second bar were rejected."),
                ("Section dock", "TC1 accepted: an icon row under the server's name. Duotone icons by default (IC2), mono line a setting (IC1). Built."),
                ("Connections", "CN5: edit inside Manage Connections, with CN2's short sheet. Rules CR1 to CR7 accepted except CR6."),
                ("EchoSense selection", "Tint while typing, solid once you use the arrows (ESR4); card material with corners following Card Corners (ESR5); rows ES1 and footer ES4; ghost text a setting, off."),
             ]),
        Info(id: "r13", label: "Round 13", title: "New tab bar directions", date: "29 Sep 2026",
             asked: "Three new single-line tab bar directions.",
             outcome: "All rejected; the tab bar went back to Round 9's strip on one line.",
             pageIDs: ["decided.round13-tab-directions"]),
        Info(id: "tree", label: "Tree card round", title: "Server card rows", date: "29 Sep 2026",
             asked: "Six ways to draw the rows inside the server card, beside today's.",
             outcome: "S4 Quiet with folders and a dimmed schema prefix.",
             pageIDs: ["decided.tree-card-s4-quiet"]),
        Info(id: "r12", label: "Round 12", title: "Two-line tabs", date: "29 Sep 2026",
             asked: "Two-line versions of the tab bar.",
             outcome: "T1 with two lines and L2's icon; later replaced by one line in Round 14.",
             pageIDs: ["decided.round12-two-line-tabs"]),
        Info(id: "r11", label: "Round 11", title: "Tab bar", date: "29 Sep 2026",
             asked: "Eight tab bar designs beside today's glass and Classic, after the glass capsule felt weak.",
             outcome: "T1 (Safari) with two lines; later replaced by one line in Round 14.",
             pageIDs: ["decided.round11-tab-bar"]),
        Info(id: "r10", label: "Round 10", title: "Footer, switcher, results and inspector", date: "29 Sep 2026",
             asked: "How the footer's right side looks, how the database switcher opens, how results enter, whether to keep the pinned header, and where the inspector goes.",
             outcome: "A glass pill per entry; a card above the chip that rises; results grow out of the footer; pinned header removed; inspector as a column of cards.",
             pageIDs: ["decided.round10-footer-and-switcher", "decided.inspector-column"]),
        Info(id: "r9", label: "Round 9", title: "Footer, scroll bar and tabs", date: "29 Sep 2026",
             asked: "What sits behind the footer, where the footer sits, whether the tree shows a scroll bar, and how the tab bar looks.",
             outcome: "Soft blur behind the footer, lifted 4pt, no tree scroll bar, a glass tab bar (later replaced).",
             pageIDs: ["decided.round9-footer-scroller-tabs"]),
        Info(id: "r3-8", label: "Rounds 3 to 8", title: "Canvas, cards, rail and results", date: "29 Sep 2026",
             asked: "How the window is built: the canvas, the server rail, opaque tree cards, the pinned header, results and notifications.",
             outcome: "A canvas with opaque cards, 16pt corners, a rail with a + and a liquid selection, glass only on controls.",
             pageIDs: ["decided.window-canvas-and-cards", "decided.rail-servers", "decided.tree-sticky-header", "decided.results-grid", "decided.toasts-and-notifications"]),
    ]

    static func info(forPage id: String) -> Info? { all.first { $0.pageIDs.contains(id) } }
}
