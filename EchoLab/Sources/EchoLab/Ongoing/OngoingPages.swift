/// Work in progress. A page is a playground the owner is judging (`.judging`), or a verdict
/// that is built into Echo and waiting for feedback (`.inEcho`). When the owner confirms it on
/// the real app, the page is frozen into `Decided/` and removed from this list.
@MainActor enum OngoingPages {
    // `Scripts/new-round.py` adds new rounds at the two ROUNDS markers; do not remove them.
    static let all: [LabPage] = [serverCard, notificationHistory , notificationToast , sectionDockSwitching , sectionDockCapsule , sectionDockSections , runButtonLook , runButtonRunning , pgTransactionState , pgOpenTransactionGuard , pgConnectionLost , pgCancel , pgScriptResults , pgErrorLocation , pgValueDisplay , pgTimeouts , mssqlValues , mssqlErrors , mssqlSessions , mssqlEncryption , pgKerberosSignin , pgClientKeyPassword , pgFailoverHosts , runIntoRunning , mssqlImport , contentDuringSlide /* ROUNDS-LIST */] + PortedPages.ongoing

    /// Round 16: the owner's bugs and feedback on the section dock (TC1) as built in Echo.
    static let serverCard = LabPage.round(
        id: "ongoing.server-card-r16", group: "Explorer tree", title: "Server card · round 16", symbol: "rectangle.stack",
        status: .judging,
        summary: "Header and dock styles, the edge under the pinned header, switching, loading, counts, selection, dock customising and PostgreSQL's sections, beside Echo today.",
        spec: LabServerCardRound.spec)

    /// Round 17: how the notification history looks in the inspector's column and opens.
    static let notificationHistory = LabPage.round(
        id: "ongoing.notification-history-r17", group: "Notifications", title: "Notification history · round 17", symbol: "bell",
        status: .judging,
        summary: "Echo today beside a timeline, cards, and a list with the message below it, each opening a notification to its whole, selectable message.",
        spec: LabNHRound.spec)

    /// Round 18: Notification toast.
    static let notificationToast = LabPage.round(
        id: "ongoing.notification-toast-r18", group: "Notifications", title: "Notification toast · round 18", symbol: "bell.badge",
        status: .judging,
        summary: "The toast as Echo draws it today beside a proposal built from the controls. Touches NTF-1.1 to 1.6, NTF-2.1 to 2.2 and NTF-3.1 to 3.6.",
        spec: NotificationToastRound.spec)

    /// Round 19: Section dock: switching.
    static let sectionDockSwitching = LabPage.round(
        id: "ongoing.section-dock-switching-r19", group: "Explorer tree", title: "Section dock: switching · round 19", symbol: "rectangle.stack",
        status: .judging,
        summary: "How a server card changes when you switch sections, and why the card above moves; changes TREE-3.7, TREE-1.2.",
        spec: SectionDockSwitchingRound.spec)

    /// Round 19: Section dock: capsule.
    static let sectionDockCapsule = LabPage.round(
        id: "ongoing.section-dock-capsule-r19", group: "Explorer tree", title: "Section dock: capsule · round 19", symbol: "capsule",
        status: .judging,
        summary: "How the section capsule looks: ten styles, icon weight and size, the current section, hover, and where the section's name shows; changes TREE-3.1 to TREE-3.3.",
        spec: SectionDockCapsuleRound.spec)

    /// Round 19: Section dock: sections.
    static let sectionDockSections = LabPage.round(
        id: "ongoing.section-dock-sections-r19", group: "Explorer tree", title: "Section dock: sections · round 19", symbol: "square.grid.2x2",
        status: .judging,
        summary: "How many sections a dock holds, how SQL Server's eight are grouped, and what happens to sections that don't fit; changes TREE-3.4, TREE-3.5.",
        spec: SectionDockSectionsRound.spec)

    /// Round 20: Run button: look.
    static let runButtonLook = LabPage.round(
        id: "ongoing.run-button-look-r20", group: "Editor and running", title: "Run button: look · round 20", symbol: "play",
        status: .judging,
        summary: "How Run looks at rest: seven forms, eight icons, five colours, the selection signal, hover, when it can't run, where its other modes live and whether it remembers the last one. Changes EDT-4.1, 4.2 and 4.5.",
        spec: RunButtonLookRound.spec)

    /// Round 20: Run button: running.
    static let runButtonRunning = LabPage.round(
        id: "ongoing.run-button-running-r20", group: "Editor and running", title: "Run button: running · round 20", symbol: "stop.circle",
        status: .judging,
        summary: "How Run moves: seven running looks, a delay so quick queries never make it expand, the timer format, the stop icon, motion while running, how it changes into running, the result and how long it stays, with scenario buttons from 0.2 s to until stopped. Changes EDT-4.3 and 4.4.",
        spec: RunButtonRunningRound.spec)

    /// Round 21: Postgres: transaction state.
    static let pgTransactionState = LabPage.round(
        id: "ongoing.pg-transaction-state-r21", group: "Footer and results", title: "Postgres: transaction state · round 21", symbol: "arrow.triangle.branch",
        status: .judging,
        summary: "Where and how a query tab shows that it is inside a transaction, failed inside one, or lost its connection.",
        spec: PgTransactionStateRound.spec)

    /// Round 21: Postgres: open transaction on close.
    static let pgOpenTransactionGuard = LabPage.round(
        id: "ongoing.pg-open-transaction-guard-r21", group: "Tabs", title: "Postgres: open transaction on close · round 21", symbol: "exclamationmark.shield",
        status: .judging,
        summary: "What happens when a tab with an open transaction is closed, switched to another database, disconnected or Echo quits.",
        spec: PgOpenTransactionGuardRound.spec)

    /// Round 21: Postgres: connection lost.
    static let pgConnectionLost = LabPage.round(
        id: "ongoing.pg-connection-lost-r21", group: "Notifications", title: "Postgres: connection lost · round 21", symbol: "bolt.horizontal.circle",
        status: .judging,
        summary: "How Echo says a tab's connection dropped (and whether a transaction was rolled back), and how it reconnects.",
        spec: PgConnectionLostRound.spec)

    /// Round 21: Postgres: cancelling a query.
    static let pgCancel = LabPage.round(
        id: "ongoing.pg-cancel-r21", group: "Editor and running", title: "Postgres: cancelling a query · round 21", symbol: "stop.circle",
        status: .judging,
        summary: "What cancelling means now that it stops the query on the server: the wait, the rows already fetched, a stuck cancel and what is reported.",
        spec: PgCancelRound.spec)

    /// Round 21: Postgres: script results.
    static let pgScriptResults = LabPage.round(
        id: "ongoing.pg-script-results-r21", group: "Footer and results", title: "Postgres: script results · round 21", symbol: "list.number",
        status: .judging,
        summary: "How the results of a script with several statements are shown.",
        spec: PgScriptResultsRound.spec)

    /// Round 21: Postgres: where the error is.
    static let pgErrorLocation = LabPage.round(
        id: "ongoing.pg-error-location-r21", group: "Editor and running", title: "Postgres: where the error is · round 21", symbol: "exclamationmark.triangle",
        status: .judging,
        summary: "How Echo points at the place in the SQL where Postgres reports an error, with its hint.",
        spec: PgErrorLocationRound.spec)

    /// Round 21: Postgres: values in the grid.
    static let pgValueDisplay = LabPage.round(
        id: "ongoing.pg-value-display-r21", group: "Footer and results", title: "Postgres: values in the grid · round 21", symbol: "tablecells",
        status: .judging,
        summary: "How PostgreSQL arrays, JSON, binary data, intervals, ranges and other types read in the results grid.",
        spec: PgValueDisplayRound.spec)

    /// Round 21: Postgres: statement timeouts.
    static let pgTimeouts = LabPage.round(
        id: "ongoing.pg-timeouts-r21", group: "Connections", title: "Postgres: statement timeouts · round 21", symbol: "timer",
        status: .judging,
        summary: "Whether and where a statement or lock timeout is set, and what Echo says when one fires.",
        spec: PgTimeoutsRound.spec)

    /// Round 22: SQL Server: values in the grid.
    static let mssqlValues = LabPage.round(
        id: "ongoing.mssql-values-r22", group: "Footer and results", title: "SQL Server: values in the grid · round 22", symbol: "tablecells",
        status: .judging,
        summary: "Values after row 200 of a SQL Server result are garbled, and dates, offsets and money lose digits; how should they read?",
        spec: MssqlValuesRound.spec)

    /// Round 22: SQL Server: errors and messages.
    static let mssqlErrors = LabPage.round(
        id: "ongoing.mssql-errors-r22", group: "Editor and running", title: "SQL Server: errors and messages · round 22", symbol: "exclamationmark.triangle",
        status: .judging,
        summary: "How should SQL Server errors show their number, severity, state and line, and what does a commit with an unknown outcome say?",
        spec: MssqlErrorsRound.spec)

    /// Round 22: SQL Server: cancel, timeouts and lost connections.
    static let mssqlSessions = LabPage.round(
        id: "ongoing.mssql-sessions-r22", group: "Editor and running", title: "SQL Server: cancel, timeouts and lost connections · round 22", symbol: "stop.circle",
        status: .judging,
        summary: "Cancel no longer throws the query tab's session away; what changes for cancel, the 45-second limit and a dropped connection?",
        spec: MssqlSessionsRound.spec)

    /// Round 22: SQL Server: encryption settings.
    static let mssqlEncryption = LabPage.round(
        id: "ongoing.mssql-encryption-r22", group: "Connections", title: "SQL Server: encryption settings · round 22", symbol: "lock.shield",
        status: .judging,
        summary: "What do Optional, Mandatory and Strict mean now, which is the default, and how does the sheet explain them?",
        spec: MssqlEncryptionRound.spec)

    /// Round 23: Postgres: Kerberos sign-in.
    static let pgKerberosSignin = LabPage.round(
        id: "ongoing.pg-kerberos-signin-r23", group: "Connections", title: "Postgres: Kerberos sign-in · round 23", symbol: "person.badge.key",
        status: .judging,
        summary: "How a PostgreSQL connection signs in with the user's Kerberos ticket: where the choice sits, what it is called, the service name, and whether the sheet shows the ticket. Changes CON-3.1, CON-3.2 and CON-4.3.",
        spec: PgKerberosSigninRound.spec)

    /// Round 23: Postgres: encrypted client key.
    static let pgClientKeyPassword = LabPage.round(
        id: "ongoing.pg-client-key-password-r23", group: "Connections", title: "Postgres: encrypted client key · round 23", symbol: "key",
        status: .judging,
        summary: "Where the password for an encrypted client key goes, when it shows and whether it is kept in the Keychain. Changes CON-4.3.",
        spec: PgClientKeyPasswordRound.spec)

    /// Round 23: Postgres: several servers and failover.
    static let pgFailoverHosts = LabPage.round(
        id: "ongoing.pg-failover-hosts-r23", group: "Connections", title: "Postgres: several servers and failover · round 23", symbol: "server.rack",
        status: .judging,
        summary: "How a connection names several servers and which one to use (primary, standby), and whether Echo says when it moves to another. Changes CON-2.3 and CON-4.3.",
        spec: PgFailoverHostsRound.spec)

    /// Round 24: Run: ▶ into ■.
    static let runIntoRunning = LabPage.round(
        id: "ongoing.run-into-running-r24", group: "Editor and running", title: "Run: ▶ into ■ · round 24", symbol: "play.square",
        status: .judging,
        summary: "The icon itself turns ▶ into ■ (seven ways, led by round 20 R1's in-place replace, with a slow-motion scrubber), then how the red arrives, how the capsule grows and the timer appears, the curve, and how it ends. Changes EDT-4.3; round 20's A2 glass morph is replaced by this.",
        spec: RunIntoRunningRound.spec)

    /// Round 25: SQL Server: importing a file.
    static let mssqlImport = LabPage.round(
        id: "ongoing.mssql-import-r25", group: "Explorer tree", title: "SQL Server: importing a file · round 25", symbol: "square.and.arrow.down",
        status: .judging,
        summary: "Imports now use the TDS bulk load. Which of its options the Import Data sheet offers (constraints, triggers, empty cells as the column default, table lock), the batch size, and whether a failed import undoes everything. No Spec element covers the sheet yet. Already fixed: SQL Server imports never moved the progress bar.",
        spec: MssqlImportRound.spec)

    /// Round 26: Tab content while the tree slides.
    static let contentDuringSlide = LabPage.round(
        id: "ongoing.content-during-slide-r26", group: "Window and cards", title: "Tab content while the tree slides · round 26", symbol: "sidebar.left",
        status: .judging,
        summary: "Changes WIN-3.2 (Hide and show) and the inspector's slide. Over the Activity Monitor the slide runs at about 20 fps, because every table cell re-lays out on every frame; over a query tab it is 60 fps.",
        spec: ContentDuringSlideRound.spec)

    // ROUNDS-DEFINITIONS
}
