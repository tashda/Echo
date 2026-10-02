/// Work in progress. A page is a playground the owner is judging (`.judging`), or a verdict
/// that is built into Echo and waiting for feedback (`.inEcho`). When the owner confirms it on
/// the real app, the page is frozen into `Decided/` and removed from this list.
@MainActor enum OngoingPages {
    // `Scripts/new-round.py` adds new rounds at the two ROUNDS markers; do not remove them.
    static let all: [LabPage] = [serverCard, notificationHistory , notificationToast , sectionDockSwitching , sectionDockCapsule , sectionDockSections , runButtonLook , runButtonRunning , pgTransactionState , pgOpenTransactionGuard , pgConnectionLost , pgCancel , pgScriptResults , pgErrorLocation , pgValueDisplay , pgTimeouts , mssqlValues , mssqlErrors , mssqlSessions , mssqlEncryption , pgKerberosSignin , pgClientKeyPassword , pgFailoverHosts , runIntoRunning , mssqlImport , contentDuringSlide , resultsScrollers , editorText , editorGutter , editorCaretLine , editorStatement , editorMarks , editorErrors , editorRunNote , editorZoom , editorFindTyping , editorEmpty , editorSettings , mssqlAlwaysEncrypted , editorFindBar , editorSearchReplace , editorGutterLane , editorDesignLanguage , serverHeaderLook , serverHeaderCollapse , emptyFolders , zoomPillFooter , panelFillsLight , panelFillsDark , agentJobsTab , agentJobStepSheet , refreshAndActivity , tabOverviewDirection , toolTabPages , toolTabPagesWhere , toolTabFamilies , toolTabHeader , toolTabControls , toolTabThemes , toolTabToolbar , treeToolRows , railTools , railBookmarks , railSnippets , railHistory , railClipboard , railClickHiddenTree , resultsHeaderLines , resultsSelectionSummary , resultsErrorPage , resultsMessages , resultsPillPopovers , contextMenuAnatomy , contextMenuServer , contextMenuDatabase , contextMenuTable , contextMenuColumn , contextMenuFolder , settingsPreview , settingsPictures , settingsControls , settingsTemplate , settingsScenarios , footerBlur , toolTabMainAction , serverCardUnfold , resultsGutter , openingAndClosing , toolTabBar , serverHeaderPolish , serverTrailIdentity , connectMenu , serverHeaderCustom , cardToTrail , trailItemStates , connectCard , headerOnScroll , headerSizes /* ROUNDS-LIST */] + PortedPages.ongoing

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

    /// Round 27: Results scroll bars and the footer.
    static let resultsScrollers = LabPage.round(
        id: "ongoing.results-scrollers-r27", group: "Footer and results", title: "Results scroll bars and the footer · round 27", symbol: "scroll",
        status: .judging,
        summary: "Changes FTR-4.6. The grid's horizontal scroll bar floats over the last rows above the footer; where should it sit so it blends in with the footer? Asked 2026-10-01 alongside the results smoothness work.",
        spec: ResultsScrollersRound.spec)

    /// Round 28: Editor: text and line height.
    static let editorText = LabPage.round(
        id: "ongoing.editor-text-r28", group: "Editor and running", title: "Editor: text and line height · round 28", symbol: "textformat.size",
        status: .judging,
        summary: "The editor's font, size, ligatures, line height and margins. Today a line is 31pt for 13pt text because the Line Spacing setting is applied twice. Changes EDT-1.2.",
        spec: EditorTextRound.spec)

    /// Round 28: Editor: gutter.
    static let editorGutter = LabPage.round(
        id: "ongoing.editor-gutter-r28", group: "Editor and running", title: "Editor: gutter · round 28", symbol: "list.number",
        status: .judging,
        summary: "The line numbers: their font, colour and size, the caret line's number (today the faintest one), the surface and where the error dot and Run arrow sit. Changes EDT-2.1 to 2.3.",
        spec: EditorGutterRound.spec)

    /// Round 28: Editor: caret, current line and selection.
    static let editorCaretLine = LabPage.round(
        id: "ongoing.editor-caret-line-r28", group: "Editor and running", title: "Editor: caret, current line and selection · round 28", symbol: "character.cursor.ibeam",
        status: .judging,
        summary: "The current-line band, the selection's colour and shape, and the caret's colour. Changes EDT-2.4.",
        spec: EditorCaretLineRound.spec)

    /// Round 28: Editor: the statement at the caret.
    static let editorStatement = LabPage.round(
        id: "ongoing.editor-statement-r28", group: "Editor and running", title: "Editor: the statement at the caret · round 28", symbol: "text.line.first.and.arrowtriangle.forward",
        status: .judging,
        summary: "How the statement at the caret shows (today a 6% accent band) and how its Run arrow looks. Changes EDT-3.1 and 3.2.",
        spec: EditorStatementRound.spec)

    /// Round 28: Editor: highlights and marks.
    static let editorMarks = LabPage.round(
        id: "ongoing.editor-marks-r28", group: "Editor and running", title: "Editor: highlights and marks · round 28", symbol: "highlighter",
        status: .judging,
        summary: "One shape language for everything drawn on the text: the word at the caret, find matches, matching brackets; corner, height, colour, and no glass on text.",
        spec: EditorMarksRound.spec)

    /// Round 28: Editor: errors in the text.
    static let editorErrors = LabPage.round(
        id: "ongoing.editor-errors-r28", group: "Editor and running", title: "Editor: errors in the text · round 28", symbol: "exclamationmark.octagon",
        status: .judging,
        summary: "The red marking: today a glowing frame and a pill while typing, a squiggle and a bubble after a run. One look for both, its message and the gutter dot. Changes EDT-2.3 and adds the live check.",
        spec: EditorErrorsRound.spec)

    /// Round 28: Editor: after a run.
    static let editorRunNote = LabPage.round(
        id: "ongoing.editor-run-note-r28", group: "Editor and running", title: "Editor: after a run · round 28", symbol: "checkmark.circle",
        status: .judging,
        summary: "The “✓ 200 rows · 10.1 s” note: its look and place, whether what ran lights up, and the row count (fixed: it counted only the rows in memory). Changes EDT-3.3.",
        spec: EditorRunNoteRound.spec)

    /// Round 28: Editor: zoom.
    static let editorZoom = LabPage.round(
        id: "ongoing.editor-zoom-r28", group: "Editor and running", title: "Editor: zoom · round 28", symbol: "plus.magnifyingglass",
        status: .judging,
        summary: "A new zoom control for the editor: where it sits, how it looks, when it shows, what it zooms and its keys. New in EDT.",
        spec: EditorZoomRound.spec)

    /// Round 28: Editor: find, go to line and typing.
    static let editorFindTyping = LabPage.round(
        id: "ongoing.editor-find-typing-r28", group: "Editor and running", title: "Editor: find, go to line and typing · round 28", symbol: "magnifyingglass",
        status: .judging,
        summary: "Find, Go to Line (an alert today), wrapping, Tab, closing brackets and keeping the indent on a new line.",
        spec: EditorFindTypingRound.spec)

    /// Round 28: Editor: empty tab and the right edge.
    static let editorEmpty = LabPage.round(
        id: "ongoing.editor-empty-r28", group: "Editor and running", title: "Editor: empty tab and the right edge · round 28", symbol: "doc",
        status: .judging,
        summary: "Where the starting points sit in an empty tab, and the outline edge against the scroll bar. Changes EDT-1.3.",
        spec: EditorEmptyRound.spec)

    /// Round 28: Editor: settings.
    static let editorSettings = LabPage.round(
        id: "ongoing.editor-settings-r28", group: "Editor and running", title: "Editor: settings · round 28", symbol: "gearshape",
        status: .judging,
        summary: "Every editor setting Echo has today, spread over three panes with five more hidden, and which should stay a setting, in one Editor pane.",
        spec: EditorSettingsRound.spec)

    /// Round 29: SQL Server: Always Encrypted columns.
    static let mssqlAlwaysEncrypted = LabPage.round(
        id: "ongoing.mssql-always-encrypted-r29", group: "Footer and results", title: "SQL Server: Always Encrypted columns · round 29", symbol: "lock.fill",
        status: .judging,
        summary: "sqlserver-nio now says which result columns are Always Encrypted (real type, deterministic or randomized, key path), but Echo has no keys, so values stay ciphertext. How encrypted cells read, a header marker with details on hover, editing, Copy, and whether Echo always asks. Touches FTR-2.3 and the cell editor.",
        spec: MssqlAlwaysEncryptedRound.spec)

    /// Round 28: Editor: the find bar.
    static let editorFindBar = LabPage.round(
        id: "ongoing.editor-find-bar-r28", group: "Editor and running", title: "Editor: the find bar · round 28", symbol: "magnifyingglass",
        status: .judging,
        summary: "The find bar itself, drawn: the system's bar above the text (today) against floating glass panels at the top right, along the top and at the bottom; its options, the match count and Replace. Asked in your notes on 28.5.",
        spec: EditorFindBarRound.spec)

    /// Round 28: Editor: search and replace.
    static let editorSearchReplace = LabPage.round(
        id: "ongoing.editor-search-replace-r28", group: "Editor and running", title: "Editor: search and replace · round 28", symbol: "arrow.2.squarepath",
        status: .judging,
        summary: "Search and replace together, on FB5's glass: how the replacement shows in the editor while you type, how the Replace row opens from the chevron, the shortcuts for Find and for Find and Replace, and the keys inside the bar. Asked in your notes on 28.12.",
        spec: EditorSearchReplaceRound.spec)

    /// Round 28: Editor: the gutter's lane.
    static let editorGutterLane = LabPage.round(
        id: "ongoing.editor-gutter-lane-r28", group: "Editor and running", title: "Editor: the gutter's lane · round 28", symbol: "sidebar.squares.left",
        status: .judging,
        summary: "The Lane gutter style, redrawn: what it holds, how the numbers sit in it, its height, corners and fill. Today it floats 25pt above the card's bottom with the numbers pushed to its right edge. Asked with your screenshots of the gutter styles.",
        spec: EditorGutterLaneRound.spec)

    /// Round 28: Editor: one design language.
    static let editorDesignLanguage = LabPage.round(
        id: "ongoing.editor-design-language-r28", group: "Editor and running", title: "Editor: one design language · round 28", symbol: "paintpalette",
        status: .judging,
        summary: "Every mark in the editor in one language: one corner, one tint scale, colour by meaning, one height, one Marks section in Settings, and one look for floating pills. Today's marks mix pills, 3pt corners and tints from 9% to 35%. Asked in your notes on 28.13.",
        spec: EditorDesignLanguageRound.spec)

    /// Round 30: Server card: the header.
    static let serverHeaderLook = LabPage.round(
        id: "ongoing.server-header-look-r30", group: "Explorer tree", title: "Server card: the header · round 30", symbol: "rectangle.topthird.inset.filled",
        status: .judging,
        summary: "The server's name, product line and dock at the top of its card. Rev 2: the five headers you kept (HD0 plain, HD4 wash, HD5 line, HD7 plate, HD8 banner) and eight variations on them, and plain, the header's colour and the dock icon's colour as settings. Changes TREE-2.1 and TREE-2.2 (server header).",
        spec: ServerHeaderLookRound.spec)

    /// Round 30: Server card: collapsing.
    static let serverHeaderCollapse = LabPage.round(
        id: "ongoing.server-header-collapse-r30", group: "Explorer tree", title: "Server card: collapsing · round 30", symbol: "chevron.down.circle",
        status: .judging,
        summary: "Where the collapse chevron sits on the two-line header, and how the card folds away and opens again, beside Echo today.",
        spec: ServerHeaderCollapseRound.spec)

    /// Round 30: Database folders that are empty.
    static let emptyFolders = LabPage.round(
        id: "ongoing.empty-folders-r30", group: "Explorer tree", title: "Database folders that are empty · round 30", symbol: "folder",
        status: .judging,
        summary: "Views is loaded but hidden: Settings › Sidebar hides empty folders, and this database has no views. Should Tables, Views, Functions and Procedures always show, and how does an empty one look?",
        spec: EmptyFoldersRound.spec)

    /// Round 31: Editor: the zoom pill and the footer.
    static let zoomPillFooter = LabPage.round(
        id: "ongoing.zoom-pill-footer-r31", group: "Editor and running", title: "Editor: the zoom pill and the footer · round 31", symbol: "plus.magnifyingglass",
        status: .judging,
        summary: "Changes round 28.8's zoom pill: where it sits with and without results, its height (21 vs the footer's 24pt) and its text colour (secondary vs the footer's primary).",
        spec: ZoomPillFooterRound.spec)

    /// Round 32: Panels: is the inspector whiter?.
    static let panelFillsLight = LabPage.round(
        id: "ongoing.panel-fills-light-r32", group: "Window and cards", title: "Panels: is the inspector whiter? · round 32", symbol: "rectangle.split.3x1",
        status: .judging,
        summary: "Measured in your screenshots: every card is pure white (255) in light mode, the inspector included; what reads as greyer elsewhere is zebra rows and grey fills (245) inside the other panels, and an empty inspector is the one card with nothing on it. What should change, if anything.",
        spec: PanelFillsLightRound.spec)

    /// Round 32: Panels in dark mode.
    static let panelFillsDark = LabPage.round(
        id: "ongoing.panel-fills-dark-r32", group: "Window and cards", title: "Panels in dark mode · round 32", symbol: "moon",
        status: .judging,
        summary: "Measured: the dark canvas is 27–29 and the cards 30 (out of 255), so only the 0.5pt edge separates them and the shadow is invisible. Canvas, card, edge and shadow options for dark mode.",
        spec: PanelFillsDarkRound.spec)

    /// Round 33: SQL Server Agent Jobs: the tab.
    static let agentJobsTab = LabPage.round(
        id: "ongoing.agent-jobs-tab-r33", group: "Tool tabs", title: "SQL Server Agent Jobs: the tab · round 33", symbol: "clock",
        status: .judging,
        summary: "The Jobs, Details and History panes as built (three header styles: Jobs and History 13pt with 12 by 6pt padding, Details 14pt with 16 by 12pt), beside one header for every pane, the layout, the Details sections, the jobs' columns and the empty rows.",
        spec: AgentJobsTabRound.spec)

    /// Round 33: SQL Server Agent Jobs: New Step.
    static let agentJobStepSheet = LabPage.round(
        id: "ongoing.agent-job-step-sheet-r33", group: "Tool tabs", title: "SQL Server Agent Jobs: New Step · round 33", symbol: "list.number",
        status: .judging,
        summary: "The sheet as built (one section repeating the title, a plain text box for the command, no On success/On failure, a bordered Add Step where the sheet rules want a prominent one) beside fuller sheets.",
        spec: AgentJobStepSheetRound.spec)

    /// Round 34: Refresh and the activity signal.
    static let refreshAndActivity = LabPage.round(
        id: "ongoing.refresh-and-activity-r34", group: "Window and cards", title: "Refresh and the activity signal · round 34", symbol: "arrow.clockwise",
        status: .judging,
        summary: "Today Refresh (RefreshToolbarButton) does two jobs: it reloads the front tab (a tool tab's data, or a query tab's database schema) and it mirrors every ActivityEngine operation for the server, query runs included, with a spinner, ✓ or ✗. Run then shows its own ✓ too. Where activity should show, where Refresh should live, and what it does on a query tab.",
        spec: RefreshAndActivityRound.spec)

    /// Round 35: Tab overview: the direction.
    static let tabOverviewDirection = LabPage.round(
        id: "ongoing.tab-overview-direction-r35", group: "Tabs", title: "Tab overview: the direction · round 35", symbol: "square.grid.2x2",
        status: .judging,
        summary: "Accepted: TO6, the palette, built into Echo as the ⌘K palette turned to this window's tabs. Trimmed to it; 35.2 to 35.4 were withdrawn with the grid.",
        spec: TabOverviewDirectionRound.spec)

    /// Round 36: Tool tabs with pages: the tab bar.
    static let toolTabPages = LabPage.round(
        id: "ongoing.tool-tab-pages-r36", group: "Tabs", title: "Tool tabs with pages: the tab bar · round 36", symbol: "rectangle.split.3x1",
        status: .judging,
        summary: "Changes ST2 (round 14): how a tool's pages sit in its tab (today a grey track capsule inside the tab), how the strip looks with one tab, and how the tab unfolds.",
        spec: ToolTabPagesRound.spec)

    /// Round 36: Tool tabs with pages: which tools.
    static let toolTabPagesWhere = LabPage.round(
        id: "ongoing.tool-tab-pages-where-r36", group: "Tabs", title: "Tool tabs with pages: which tools · round 36", symbol: "square.stack.3d.up",
        status: .judging,
        summary: "Nine other tools switch sections with a segmented control inside the tab. Which should get pages in the tab bar, and what happens when there are more pages than fit (Database Security has nine).",
        spec: ToolTabPagesWhereRound.spec)

    /// Round 37: Tool tabs: the families.
    static let toolTabFamilies = LabPage.round(
        id: "ongoing.tool-tab-families-r37", group: "Tool tabs", title: "Tool tabs: the families · round 37", symbol: "square.grid.3x2",
        status: .judging,
        summary: "Every tool tab Echo has, sorted into five families by the shape of their work (monitor, manage, health, properties, canvas). Decide the families first; 37.2 to 37.4 design them.",
        spec: ToolTabFamiliesRound.spec)

    /// Round 37: Tool tabs: the header and toolbar row.
    static let toolTabHeader = LabPage.round(
        id: "ongoing.tool-tab-header-r37", group: "Tool tabs", title: "Tool tabs: the header and toolbar row · round 37", symbol: "rectangle.topthird.inset.filled",
        status: .judging,
        summary: "The one header and toolbar row for every tool tab (changes TLT-1 and TLT-2): five layouts drawn on SQL Profiler, Policy Management and Activity Monitor.",
        spec: ToolTabHeaderRound.spec)

    /// Round 37: Tool tabs: buttons and controls.
    static let toolTabControls = LabPage.round(
        id: "ongoing.tool-tab-controls-r37", group: "Tool tabs", title: "Tool tabs: buttons and controls · round 37", symbol: "button.horizontal",
        status: .judging,
        summary: "The vocabulary: a primary action like Start Trace, icon buttons, pickers like Database: All Databases, a running status and search, in the editor's glass language.",
        spec: ToolTabControlsRound.spec)

    /// Round 37: Tool tabs: a theme per family.
    static let toolTabThemes = LabPage.round(
        id: "ongoing.tool-tab-themes-r37", group: "Tool tabs", title: "Tool tabs: a theme per family · round 37", symbol: "paintpalette",
        status: .judging,
        summary: "Each family's tab in the unified design: monitor, manage, health, properties and canvas.",
        spec: ToolTabThemesRound.spec)

    /// Round 37.5: the tab's own buttons in the toolbar, tied to the tab.
    static let toolTabToolbar = LabPage.round(
        id: "ongoing.tool-tab-toolbar-r37", group: "Tool tabs", title: "Tool tabs: the tab's own buttons in the toolbar · round 37", symbol: "menubar.rectangle",
        status: .judging,
        summary: "Every tab's dedicated buttons go in the window toolbar, at the right before the window's icons, and show that they belong to the tab in front: eight ties, four ways to show several groups (the query editor has three), three Runs, what moves from a tool's header line, and the motion when you switch tabs. Replaces round 45; changes TLT-10 and the editor's toolbar (EDT Run).",
        spec: ToolTabToolbarRound.spec)

    /// Round 38: Tree rows that open a tab.
    static let treeToolRows = LabPage.round(
        id: "ongoing.tree-tool-rows-r38", group: "Explorer tree", title: "Tree rows that open a tab · round 38", symbol: "arrow.up.right.square",
        status: .judging,
        summary: "Today Open Security Management is only in the right-click menus of the server's and a database's Security; Agent Jobs Overview is a row that opens a tab but looks like any other row. Where the new row goes, what it's called, and the mark for rows that open a tab or a window.",
        spec: TreeToolRowsRound.spec)

    /// Round 39: Rail tools: keep, merge or move.
    static let railTools = LabPage.round(
        id: "ongoing.rail-tools-r39", group: "Window and cards", title: "Rail tools: keep, merge or move · round 39", symbol: "square.stack",
        status: .judging,
        summary: "Today each opens in place of the tree. History is a Coming Soon placeholder, Snippets is the built-in catalog only, Clipboard is Echo's own copy history (macOS 26 has one in Spotlight), Bookmarks saves SQL per server. Which stay, where they live, and how you reach them.",
        spec: RailToolsRound.spec)

    /// Round 39: Rail tools: Bookmarks.
    static let railBookmarks = LabPage.round(
        id: "ongoing.rail-bookmarks-r39", group: "Window and cards", title: "Rail tools: Bookmarks · round 39", symbol: "bookmark",
        status: .judging,
        summary: "How you save a query to Bookmarks, what a bookmark holds, how the list looks and what opening one does.",
        spec: RailBookmarksRound.spec)

    /// Round 39: Rail tools: Snippets.
    static let railSnippets = LabPage.round(
        id: "ongoing.rail-snippets-r39", group: "Window and cards", title: "Rail tools: Snippets · round 39", symbol: "curlybraces",
        status: .judging,
        summary: "Built-in and your own snippets: how you find them, insert them (click, drag, typing) and write your own.",
        spec: RailSnippetsRound.spec)

    /// Round 39: Rail tools: History.
    static let railHistory = LabPage.round(
        id: "ongoing.rail-history-r39", group: "Window and cards", title: "Rail tools: History · round 39", symbol: "clock.arrow.circlepath",
        status: .judging,
        summary: "A real query history in place of today's Coming Soon: what is kept, how it reads, search, and running a query again.",
        spec: RailHistoryRound.spec)

    /// Round 39: Rail tools: Clipboard.
    static let railClipboard = LabPage.round(
        id: "ongoing.rail-clipboard-r39", group: "Window and cards", title: "Rail tools: Clipboard · round 39", symbol: "list.clipboard",
        status: .judging,
        summary: "Whether Echo needs its own clipboard history now that macOS 26 keeps one in Spotlight, and what to keep from it.",
        spec: RailClipboardRound.spec)

    /// Round 40: Clicking a server while the tree is hidden.
    static let railClickHiddenTree = LabPage.round(
        id: "ongoing.rail-click-hidden-tree-r40", group: "Window and cards", title: "Clicking a server while the tree is hidden · round 40", symbol: "sidebar.left",
        status: .judging,
        summary: "Today (WorkspaceShell, ServerRailClick) a plain click peeks: the tree slides out on glass over the cards until you click outside or press Esc; ⌘-click or a double-click shows the tree. Changes the rail decision (round 3–8) as you asked; this page decides the details.",
        spec: RailClickHiddenTreeRound.spec)

    /// Round 41: Results: the column header's lines.
    static let resultsHeaderLines = LabPage.round(
        id: "ongoing.results-header-lines-r41", group: "Footer and results", title: "Results: the column header's lines · round 41", symbol: "line.3.horizontal",
        status: .judging,
        summary: "Measured in your screenshot: a 1pt line under the header and a second 0.5pt line about 4pt below it. ResultTableHeaderView.draw adds a full-width separator on top of the one the system header draws. One line, which, or none.",
        spec: ResultsHeaderLinesRound.spec)

    /// Round 41: Results: the selection summary.
    static let resultsSelectionSummary = LabPage.round(
        id: "ongoing.results-selection-summary-r41", group: "Footer and results", title: "Results: the selection summary · round 41", symbol: "sum",
        status: .judging,
        summary: "The selection pill (today 89 cells · Sum 34.630.054.833.231 · Avg …) made compact, with a popover of exact figures you can copy.",
        spec: ResultsSelectionSummaryRound.spec)

    /// Round 41: Results: the error page and its neighbours.
    static let resultsErrorPage = LabPage.round(
        id: "ongoing.results-error-page-r41", group: "Footer and results", title: "Results: the error page and its neighbours · round 41", symbol: "exclamationmark.octagon",
        status: .judging,
        summary: "How a failed query shows in the results card beside the other states (rows affected, no rows, cancelled, lost connection, running), and whether the editor highlights the statement's first word.",
        spec: ResultsErrorPageRound.spec)

    /// Round 41: Results: the Messages panel.
    static let resultsMessages = LabPage.round(
        id: "ongoing.results-messages-r41", group: "Footer and results", title: "Results: the Messages panel · round 41", symbol: "text.bubble",
        status: .judging,
        summary: "The Messages panel without its distractions: categories, two time columns, pink rows, debug metrics and a trash button over Warnings.",
        spec: ResultsMessagesRound.spec)

    /// Round 41: Results: a popover for each footer pill.
    static let resultsPillPopovers = LabPage.round(
        id: "ongoing.results-pill-popovers-r41", group: "Footer and results", title: "Results: a popover for each footer pill · round 41", symbol: "rectangle.3.group.bubble",
        status: .judging,
        summary: "Rows, time and status each open their own popover with what that pill is about, instead of one general one.",
        spec: ResultsPillPopoversRound.spec)

    /// Round 42: Context menus: the rules.
    static let contextMenuAnatomy = LabPage.round(
        id: "ongoing.context-menu-anatomy-r42", group: "Explorer tree", title: "Context menus: the rules · round 42", symbol: "contextualmenu.and.cursorarrow",
        status: .judging,
        summary: "One set of rules for every menu, from Apple's guidelines (short, about three groups, most used first, one level of submenus, hide what doesn't apply, no shortcuts, destructive last, familiar icons): order, icons, where Properties and Drop go, a title, Copy Name. Pages 42.2 to 42.6 apply them object by object.",
        spec: ContextMenuAnatomyRound.spec)

    /// Round 42: Context menus: server.
    static let contextMenuServer = LabPage.round(
        id: "ongoing.context-menu-server-r42", group: "Explorer tree", title: "Context menus: server · round 42", symbol: "server.rack",
        status: .judging,
        summary: "The server's menu: today Refresh All, New Query, Activity Monitor, five tools, Manage Connection, Disconnect, Properties in six groups.",
        spec: ContextMenuServerRound.spec)

    /// Round 42: Context menus: database.
    static let contextMenuDatabase = LabPage.round(
        id: "ongoing.context-menu-database-r42", group: "Explorer tree", title: "Context menus: database · round 42", symbol: "cylinder",
        status: .judging,
        summary: "The database's menu: today Refresh Schema, New Query, Maintenance, Tasks (up to 14 items), Advanced Objects, Drop and Properties.",
        spec: ContextMenuDatabaseRound.spec)

    /// Round 42: Context menus: tables and views.
    static let contextMenuTable = LabPage.round(
        id: "ongoing.context-menu-table-r42", group: "Explorer tree", title: "Context menus: tables and views · round 42", symbol: "tablecells",
        status: .judging,
        summary: "The table's and view's menu, as in your screenshot: New Query, Data, Structure, Diagram, Script as, Tasks, Drop Table, Properties in five groups.",
        spec: ContextMenuTableRound.spec)

    /// Round 42: Context menus: columns, routines and the rest.
    static let contextMenuColumn = LabPage.round(
        id: "ongoing.context-menu-column-r42", group: "Explorer tree", title: "Context menus: columns, routines and the rest · round 42", symbol: "list.bullet.indent",
        status: .judging,
        summary: "Columns have no menu today; procedures, functions, logins and jobs each have their own. What each should offer.",
        spec: ContextMenuColumnRound.spec)

    /// Round 42: Context menus: folders and sections.
    static let contextMenuFolder = LabPage.round(
        id: "ongoing.context-menu-folder-r42", group: "Explorer tree", title: "Context menus: folders and sections · round 42", symbol: "folder",
        status: .judging,
        summary: "Tables, Security, Agent Jobs and the other folders: what right-clicking a folder offers.",
        spec: ContextMenuFolderRound.spec)

    /// Round 43: Settings: the page and its preview.
    static let settingsPreview = LabPage.round(
        id: "ongoing.settings-preview-r43", group: "Foundations", title: "Settings: the page and its preview · round 43", symbol: "gearshape",
        status: .judging,
        summary: "Today Settings › Editor has one font preview near the top that scrolls away, and a gutter style explained in a sentence. Where a live preview sits so every change shows (top, pinned, per section, beside the settings), drawn on an editor that follows every Editor setting.",
        spec: SettingsPreviewRound.spec)

    /// Round 43: Settings: a picture for every choice.
    static let settingsPictures = LabPage.round(
        id: "ongoing.settings-pictures-r43", group: "Foundations", title: "Settings: a picture for every choice · round 43", symbol: "photo.on.rectangle",
        status: .judging,
        summary: "Choices shown as what they look like (gutter styles, mark corners and strength as small renderings) instead of words, and the preview pointing at what a setting changed.",
        spec: SettingsPicturesRound.spec)

    /// Round 43: Settings: controls and words.
    static let settingsControls = LabPage.round(
        id: "ongoing.settings-controls-r43", group: "Foundations", title: "Settings: controls and words · round 43", symbol: "switch.2",
        status: .judging,
        summary: "One vocabulary for settings: switches, choices, numbers, descriptions, the info button and resetting a single setting.",
        spec: SettingsControlsRound.spec)

    /// Round 43: Settings: the template on other pages.
    static let settingsTemplate = LabPage.round(
        id: "ongoing.settings-template-r43", group: "Foundations", title: "Settings: the template on other pages · round 43", symbol: "rectangle.stack",
        status: .judging,
        summary: "The Editor page's design applied to Results, Sidebar and Appearance, to check it works as the template for every page.",
        spec: SettingsTemplateRound.spec)

    /// Round 43: Settings: search, reset and overrides.
    static let settingsScenarios = LabPage.round(
        id: "ongoing.settings-scenarios-r43", group: "Foundations", title: "Settings: search, reset and overrides · round 43", symbol: "magnifyingglass",
        status: .judging,
        summary: "Finding a setting, seeing what you changed, resetting, settings per connection, and what syncs.",
        spec: SettingsScenariosRound.spec)

    /// Round 44: The blur under the footer.
    static let footerBlur = LabPage.round(
        id: "ongoing.footer-blur-r44", group: "Footer and results", title: "The blur under the footer · round 44", symbol: "drop.halffull",
        status: .judging,
        summary: "Changes FTR's footer blur (LayoutTokens.EdgeBlur, BackdropEdgeBlur). Every technique that can blur the rows under the footer, each drawn over the same real AppKit grid with Echo's footer, with shared controls for strength, height, curve and tint.",
        spec: FooterBlurRound.spec)

    /// Round 45: Tool tabs: the main action in the toolbar.
    static let toolTabMainAction = LabPage.round(
        id: "ongoing.tool-tab-main-action-r45", group: "Tool tabs", title: "Tool tabs: the main action in the toolbar · round 45", symbol: "play.rectangle",
        status: .judging,
        summary: "Moves each tool's main action out of its header into the window toolbar: start-and-stop actions in Run's place, with Run's running look; actions that create something as a +. Changes 37.3's PA1 and ST1 placement (TLT-2).",
        spec: ToolTabMainActionRound.spec)

    /// Round 46: Server card: opening and closing.
    static let serverCardUnfold = LabPage.round(
        id: "ongoing.server-card-unfold-r46", group: "Explorer tree", title: "Server card: opening and closing · round 46", symbol: "rectangle.expand.vertical",
        status: .judging,
        summary: "How the dock and the rows arrive when a server card opens, and leave when it closes, beside Echo today and a section switch. Changes TREE-2.5.",
        spec: ServerCardUnfoldRound.spec)

    /// Round 47: Results: the row-number gutter and the column header.
    static let resultsGutter = LabPage.round(
        id: "ongoing.results-gutter-r47", group: "Footer and results", title: "Results: the row-number gutter and the column header · round 47", symbol: "list.number",
        status: .judging,
        summary: "The results' row-number column and column header look off (the header's names don't line up with the right-aligned numbers, two lines under the header); make the gutter as good and consistent as the editor's, keeping everything it does.",
        spec: ResultsGutterRound.spec)

    /// Round 48: Opening, connecting and closing the last tab.
    static let openingAndClosing = LabPage.round(
        id: "ongoing.opening-and-closing-r48", group: "Window and cards", title: "Opening, connecting and closing the last tab · round 48", symbol: "play.rectangle",
        status: .judging,
        summary: "Three moments at the edges of a session, drawn as one staged story. The welcome loses the name and the mark echoes in as on echodb.dev; connecting stops shoving the welcome aside and lets the server page arrive; closing the last tab returns to the connected server's page instead of the welcome (today the tab delegate clears the active session). Touches WIN-welcome and server page elements.",
        spec: OpeningAndClosingRound.spec)

    /// Round 49: Tool tabs: every page, calmer switching, icons.
    static let toolTabBar = LabPage.round(
        id: "ongoing.tool-tab-bar-r49", group: "Tabs", title: "Tool tabs: every page, calmer switching, icons · round 49", symbol: "rectangle.3.group",
        status: .judging,
        summary: "Show every page of a tool in its tab (no More menu), make switching tabs smooth, redo the tab icons, and remove the server dot from tabs and the results pill",
        spec: ToolTabBarRound.spec)

    /// Round 50: Server card: a header that looks designed.
    static let serverHeaderPolish = LabPage.round(
        id: "ongoing.server-header-polish-r50", group: "Explorer tree", title: "Server card: a header that looks designed · round 50", symbol: "rectangle.topthird.inset.filled",
        status: .judging,
        summary: "Every server card header from round 30 is about 90% there but still looks AI-made rather than professionally designed: the font, the colours, the placement of items. Explore many more directions to narrow down where the card should go.",
        spec: ServerHeaderPolishRound.spec)

    /// Round 51: Server trail: telling servers apart, and a shelf for minimized cards.
    static let serverTrailIdentity = LabPage.round(
        id: "ongoing.server-trail-identity-r51", group: "Explorer tree", title: "Server trail: telling servers apart, and a shelf for minimized cards · round 51", symbol: "circle.grid.2x2",
        status: .judging,
        summary: "Minimized server cards are opened from the server trail, but the trail's two-letter monograms are too generic to spot a server in under a second. Offer levels of customization for the trail's items, and maybe a place where minimized cards can be retrieved (while keeping that distinct from the trail).",
        spec: ServerTrailIdentityRound.spec)

    /// Round 52: The + button: connecting to a server.
    static let connectMenu = LabPage.round(
        id: "ongoing.connect-menu-r52", group: "Explorer tree", title: "The + button: connecting to a server · round 52", symbol: "plus.circle",
        status: .judging,
        summary: "The + in the server trail opens a context menu below it: too little, a poor way to show saved connections, and a menu under a liquid-glass pill feels off. Explore opening to the right of the +, the + animating into a chevron, and better ways to list saved connections.",
        spec: ConnectMenuRound.spec)

    /// Round 53: Server card header: customization and the chevron.
    static let serverHeaderCustom = LabPage.round(
        id: "ongoing.server-header-custom-r53", group: "Explorer tree", title: "Server card header: customization and the chevron · round 53", symbol: "slider.horizontal.3",
        status: .judging,
        summary: "Take round 50's chosen header (F5, hairline edge, bold eyebrow over a semibold 22 name, filled selected icon, no underline or pill) and suggest simple customizations to offer users beyond colour and icon colour (fonts, sizes and so on), and show chevron ideas, since today's is too basic and does not animate.",
        spec: ServerHeaderCustomRound.spec)

    /// Round 54: Minimizing a card into the trail.
    static let cardToTrail = LabPage.round(
        id: "ongoing.card-to-trail-r54", group: "Explorer tree", title: "Minimizing a card into the trail · round 54", symbol: "arrow.down.right.and.arrow.up.left",
        status: .judging,
        summary: "Show different animations for how a server card is moved into the server trail when it is minimized (and brought back), since a closed card now leaves the tree and its trail item takes a dashed ring.",
        spec: CardToTrailRound.spec)

    /// Round 55: Trail items: open, minimized and recent servers.
    static let trailItemStates = LabPage.round(
        id: "ongoing.trail-item-states-r55", group: "Explorer tree", title: "Trail items: open, minimized and recent servers · round 55", symbol: "circle.dotted.circle",
        status: .judging,
        summary: "The dashed ring for a minimized server looks ugly. Show how a trail item should look when its server is connected and open or connected and minimized, and whether the trail should also show recently connected servers (dimmed, in the same pill or in a second pill) that connect when clicked and move into the active group.",
        spec: TrailItemStatesRound.spec)

    /// Round 56: The connect card, now its own button.
    static let connectCard = LabPage.round(
        id: "ongoing.connect-card-r56", group: "Explorer tree", title: "The connect card, now its own button · round 56", symbol: "rectangle.on.rectangle",
        status: .judging,
        summary: "The connect button is now its own glass circle under the pills, but its card still opens as if from the top group of active servers. Decide how the card should open from a button of its own, what it holds now that the connected servers are visible beside it, how the button behaves while the card is open, and that clicking outside dismisses it as well as the x.",
        spec: ConnectCardRound.spec)

    /// Round 57: The card header while the list scrolls.
    static let headerOnScroll = LabPage.round(
        id: "ongoing.header-on-scroll-r57", group: "Explorer tree", title: "The card header while the list scrolls · round 57", symbol: "arrow.up.and.down.text.horizontal",
        status: .judging,
        summary: "When a card's list scrolls, the pinned banner header cuts the rows off with a hard edge and looks bad. Show how the header and the icon menu should behave: rounded bottom corners, the icon menu scrolling away first and then the header, collapsing, or something else.",
        spec: HeaderOnScrollRound.spec)

    /// Round 58: Smaller card headers and what each setting does.
    static let headerSizes = LabPage.round(
        id: "ongoing.header-sizes-r58", group: "Explorer tree", title: "Smaller card headers and what each setting does · round 58", symbol: "textformat.size",
        status: .judging,
        summary: "The card headers feel too big even at Small with Banner with Title. Show variations that are smaller, and define exactly what each customization does (Line Above the Name = None must be only the name and tight) with the header's heights shown.",
        spec: HeaderSizesRound.spec)

    // ROUNDS-DEFINITIONS
}
