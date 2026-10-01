# Decision log

Newest first. Each entry says what was decided, and where the rule now lives. When a rule changes, add an entry; never rewrite an old one.

## 2026-10-01 · Round 42 built into Echo

Every pick of round 42 is in the running app except a database's Diagram (Echo draws only tables). Where a pick needed a choice: **Rename** opens the ALTER in a query tab to read and run, as Drop does, instead of running it from the tree; **Advanced Objects** are four flat items in Open Tool (one level of submenus); **New Connection** in the empty space opens Manage Connections. The Object menu in the menu bar is the selected row's context menu, built by the same code.

## 2026-10-01 · Round 43 accepted: Settings › Editor is the template for every settings page

Echo Labs › Foundations › Settings (43.1 to 43.5). Accepted: **one live preview pinned above the settings** (PV1) that follows every setting on the page (PS0); **no preview on pages with nothing to show** (PN0); **small pictures for choices that change a look** (CH1, PC0), the preview just changing, no ring (FB0); **a short line only where the title isn't enough, the rest in ⓘ** (DS1); **a ↺ beside a setting that isn't the default** (RS1); **switches** (TG0); **a stepper with its unit, typing allowed** (NU0); **sections named by what they change** (SN0); the template for every page with something to show (TP0) as **one `SettingsPage(preview:sections:)`** in the design system (TC0); **a search field listing matching settings across pages** (SE2); **Reset This Page at the bottom with a confirmation** (RP0); **a few settings per connection, chosen deliberately** (PC0); **sync everything except window sizes and this Mac's paths** (SY0). Not wanted: a dot beside pages with changes (MD1).

- The owner's notes: on **Sidebar** the preview is **a narrow, true-to-life server card**, not stretched to the window's edge; on **Appearance** the template does **not** apply, because the application you are in is the preview.
- Built: `SettingsPage`, `PictureChoicePicker`, `PropertyRow.resetAction`, the Editor page (live editor preview, pictures, stepper, ↺, Reset This Page), previews on Results and Sidebar, and Settings search. Not built yet: per-connection settings (PC0) and the settings sync (SY0); both need their own design of what is stored, so they stay on `Design/plan.md` as SE5 and SE6.

## 2026-10-01 · Round 42 accepted: one set of rules for every context menu

Echo Labs › Explorer tree › Context menus (42.1 to 42.6). Accepted: **one order everywhere** (open and create; Copy Name, Script as, Tasks, Open Tool; Refresh and connection commands; Drop; Properties last), **icons only on familiar actions** (New, Copy, Refresh, Properties, Drop), **no title**, **Copy Name in every object's menu**, **Drop in plain text in its own group**, **inapplicable commands hidden**, and an **Object menu** in the menu bar.

- **Server:** Open Tool submenu for the tools, Refresh (not Refresh All), Edit Connection.
- **Database:** Back Up and Restore in the menu itself, Query Builder beside New Query, Advanced Objects folded into Open Tool.
- **Table and view:** Open Data, Edit Structure, Diagram; Truncate Table in Tasks; views the same shape; double-click opens data.
- **Column:** a menu with Open Data Sorted, Insert in Query, Copy Name and Qualified Name, inline Rename that shows the ALTER; **routines:** Execute opens a tab with EXEC and the parameters.
- **Folders:** the first item is the thing you create there, a Filter in every object folder, and an empty-space menu (New Connection, Refresh All Servers, Show Empty Folders).
- Built so far: the order and icon rules, server, database, table/view, column (without Insert in Query and Rename) and folder order. Still to build: Filter, empty-space menu, double-click, the Object menu, Insert in Query, inline Rename.

## 2026-10-01 · Round 36.1 accepted: a tool's pages in its tab, refined

Echo Labs › Tabs › Tool tabs with pages: the tab bar · round 36.1, revision 3. The owner kept TP0 (the tool's title, then its pages, in the active tab) and set every other style aside; the round refined it one fix at a time.

- **Width (RW1):** the active tool tab is **exactly as wide as its title, hairline and pages** (never more than 62% of the strip); the other tabs share the rest. It no longer stretches and centres its content.
- **Track (RT2):** **no grey track**: the pages sit on the white tab itself; **the shown page is semibold on a soft pill** (primary at 6%, RC0 as drawn).
- **Type (RX1):** title and pages **at 11pt on one baseline**; the title medium while the pages show.
- **Between (RD1):** **a short hairline** (1 × 12pt) between the title and the pages.
- **Alone (SW1):** a lone tool tab keeps its own width at the leading edge, on the full grey plate.
- **Motion (UF1):** it unfolds and folds on **the house spring**; the pages fade out first and in once the tab has widened. → TABS-5.1 to 5.4, `05-components` › Tabs

## 2026-10-01 · Rounds 36.2 and 37.1, 37.3, 37.4 accepted: pages for every tool, and one design for tool tabs

Echo Labs › Tabs › round 36 and Tool tabs › round 37. Asked: introduce the pages everywhere they're needed (Policy Management had none), and one design theme for every tab except the query editor. Still being judged: the header on one line (37.2, revision 2) and where the main action lives (round 45, from the owner's note on 37.3).

- **36.2 Which tools (WP1, OF1, RM0):** **every tool whose sections are separate views** has its pages in the tab: Activity Monitor, Maintenance, Server Properties, Database Security, Server Security, Policy Management, Advanced Objects, Tuning Advisor and Error Log. Query Store is a page of Maintenance, so its own two views stay a segmented control inside that page. The tools' segmented control inside the tab goes. Pages that don't fit go into a **More** menu at the end. A tool reopens on **the last page you used on that server**. → `05-components` › Tabs, plan TL6
- **37.1 Families (FA0, QS1, PS0, UT1):** tool tabs come in five families by the shape of their work: **Monitor** (Activity Monitor, SQL Profiler, Extended Events), **Manage** (Agent Jobs, Server and Database Security, Policy Management, Availability Groups, Resource Governor, Extensions, Advanced Objects, Database Mail), **Health** (Maintenance, Tuning Advisor, Error Log, and **Query Store**, since it finds regressions to fix), **Properties** (Server Properties, Table and Extension Structure) and **Canvas** (Schema Diagram, Query Builder, Schema Diff). The psql console is not a tool tab: it follows the editor (round 28). **One theme for all:** the header, plus the same pane cards, tables and empty states. → `05-components` › Tool tabs, plan TL7
- **37.3 Controls (PA1, SA2, PK1, ST1, SF1, CH0):** the main action is a **glass capsule, its symbol in colour and its word in grey**; the other actions sit **together in one glass capsule**; a picker is **one glass pill: symbol, value and a chevron**; running, the main action **turns into Stop with a pulsing dot**; search is **a glass capsule at the right of the row**; every control is **28pt**, as the toolbar's capsules. Where the main action lives is round 45. → `05-components` › Tool tabs, plan TL8
- **37.4 A theme per family (MO0, MA0, HE0, PR0, CA0):** Monitor opens on **tiles**; Manage shows **a details card beside the list**; Health's findings each carry **a fix** (Fix, Back Up Now, Rebuild); Properties has **an Apply bar at the bottom with the number of changes**; Canvas tools keep their tools in **a floating glass bar at the bottom**. → `05-components` › Tool tabs, plan TL9

## 2026-10-01 · Round 33.2 accepted: New Step and Edit Step

Echo Labs › Tool tabs › SQL Server Agent Jobs: New Step · round 33, page 2, revision 2. The owner's picks where they differ from the recommendation are marked.

- **Layout (NS4, owner's pick over NS3):** wide, 760 by 480pt at least: the command **full height at the left**, the settings in a **sidebar at the right** (300pt, the canvas colour): Step, then When it finishes. The title names the job ("New Step · Nightly").
- **Edges (SE1):** **no hairlines**: title, content and buttons on one surface. This is `SheetLayout`, so **every sheet** loses the hairline over its buttons (VISUAL_GUIDELINES › Sheets updated).
- **Command (CE2):** Echo's SQL editor (highlighting, line numbers) with **Parse**, which checks the T-SQL without running it (`SET PARSEONLY`, sqlserver-nio `scripts.parse`) and marks the failing line in the editor as a failed query's is. Open in Editor stays. Other step types keep a plain monospaced editor.
- **When it finishes (OC1):** On success and On failure (go to the next step, quit reporting success or failure, go to step N), Retry attempts and Retry interval, saved with `configureStep`. A new step goes to the next step on success and quits reporting failure, as SSMS does.
- **Add Step (PB1):** prominent while it can be pressed, as every sheet: `SheetLayout` now makes its default button prominent when enabled (it was always bordered), and `SheetLayout.primaryButton` serves custom footers.
- **Editing a step (ES1):** a line under the title, "Last run 26 Sep 23:00 · Succeeded · 14 min", from the job's history. Edit Step shows the name and type without letting them change, since the driver can't rename a step or change its type (they were editable and silently ignored). → `05-components` › Tool tabs, plan TL5

## 2026-10-01 · After round 35.1: ⌘D, Esc, and unsaved tabs

The owner's notes on the running app, decided in chat.

- **⌘D** didn't duplicate: `duplicateTab` was an empty stub. It now opens a copy of a query tab right after it. **Esc** now closes the tab overview wherever focus is. → TABS-7.4, 7.5
- **Unsaved changes:** a query tab asks before its changes are lost, in a standard alert (owner: "a pop up like when closing a page with unsaved changes"). Save keeps it as a bookmark, Save As writes a .sql file ("Both"); a tab is unsaved once you changed it (recommended); several at once ask once (recommended). Quitting and switching project ask too, since Echo doesn't restore tabs. → `05-components` › Tab overview, TABS-8, plan O5
- **Table structure uses the same alert** (owner, 2026-10-01): the editor's own SwiftUI "Unsaved Changes" alert is gone; a structure with changes not applied asks through `WindowAlert` with Apply Changes, Discard Changes, Cancel. → TABS-8.5

## 2026-10-01 · Round 46 accepted: a server card opens and closes like a section switch

Echo Labs › Explorer tree › Server card: opening and closing · round 46, after the owner checked 30.2 in Echo (the dock and rows "just appeared": the list turned animation off whenever dock selections changed, which opening a docked server does). Every recommendation was taken. Built in 9aaec7e9.

- **Dock (DA2):** grows out of the header, from 92% and slightly out of focus, as the edge uncovers it. **It never fades** (owner's note: the glass must blur from the first frame, with no hard line during the animation).
- **Rows (RA1):** they come in **under the section switch's veil**: hidden under the card's colour while the edge glides, then the veil fades away (0.22s).
- **Closing (CL2):** the veil covers the rows (0.12s), then the card folds as the dock shrinks back into the header.
- A fold keeps the list's animation; only a section switch turns it off. → TREE-2.5

## 2026-10-01 · Round 44 accepted: the rows soften into the system's material under the footer

Echo Labs › Footer and results › The blur under the footer · round 44, after the owner saw the blur as a band twice. The round showed every technique over the same real grid; looking at them showed why the band never went away: the stacked blur layers show either full or not at all instead of fading in, so a row went from sharp to mush at once whatever the steps. Built in b5eebdb9.

- **Technique: BT4 · the system's material** (the owner's pick over my recommendation, one Core Image variable blur): the ultra-thin material behind every floating footer. Stacked steps (Echo until now), one Core Image variable blur and a plain fade to the card were not chosen. → FTR-2.2
- **Reach: BH3 · 40pt above the footer** (`EdgeBlur.materialReach`); **growth: CV6 · exponential**, (e^(4.5t) − 1) / (e^4.5 − 1), only 10% half way up, so no row meets it at once; **tint: TT1 · 15%** of the card's colour over it.
- **The scroll bar under a footer:** the material already reaches past it, so the AppKit blur that rose past the bar (round 27, U5) is off under footers; the material lies over the bar at about 6%. Every other horizontal bar in Echo keeps its rising blur. → FTR-4.6

## 2026-10-01 · Round 41 accepted: the results card's header line, selection pill, error banner, Messages and pill popovers

Echo Labs › Footer and results › round 41, five pages. Asked: double lines under the column header, a selection pill too wide to read, the error page, a noisy Messages panel, and one popover for every footer pill.

- **41.1 Header line (HL1, VD0):** one hairline under the column header, the system header's own; Echo's extra full-width line is gone. The short column dividers stay (they show where to drag a width). → FTR-4.2
- **41.2 Selection (SP3, the owner's pick over SP1; PO1, FG1, TX0):** the pill is **only the count** ("89 cells"). Clicking it opens a popover with the exact figures: Count, Sum, Average, Min, Max, Median, Distinct and Empty (NULL) for numbers; Count, Distinct and Empty for text. Each line has a Copy button under the pointer; Copy All copies label–tab–value lines. Figures are exact (decimal arithmetic), keeping the selection's decimals. → FTR-2.8
- **41.3 Error page (EP1, HL0, ED0, EA1):** a failure is **a banner at the top left of the card**: the red symbol, "Failed on line 7", the message, SQL Server's Msg · Level · State as quiet chips, and Show in Editor, Messages and **Copy Error**. Running, No rows and Cancelled use the same banner. The editor keeps its red pill on the statement's first word (the owner's pick over HL2). → FTR-1.3
- **41.4 Messages (ML1, EE1, DM1, MT1, EM0):** grouped **by statement** (a "Line 7 · select …" heading, its messages under it); errors are a red symbol and a semibold message with no fill; the counts at the top ("1 error · 2 messages") filter, copy and clear are in a ⋯ menu; the grey strip, category and delta columns, Echo's own started/finished/failed lines and the execution metrics row are gone (the metrics moved to the time popover). → FTR-5.1 to 5.3
- **41.5 Pill popovers (PP2, PR0, PT0, PS0):** **each pill opens its own popover with its actions.** Rows: rows and columns, result set N of M, loaded of total, memory; Export… and Copy All. Time: a timeline (sending, waiting for the first row, reading rows), started and finished, this tab's last runs; Run Again. Status: what happened and when, the transaction; Cancel, Commit / Roll Back (round 21's status menu, now in the popover), Show in Editor, Messages, Run Again. **Not yet:** server CPU and the session (SPID): the drivers don't report them to Echo. → FTR-2.5, 2.9 to 2.11

## 2026-10-01 · Round 38 accepted: Security Overview, and a ↗ on rows that open a tab

Echo Labs › Explorer tree › Tree rows that open a tab · round 38. Built in 9498ca2b.

- **Row (SN1):** **Security Overview**, like Agent Jobs Overview, the **first row in every SQL Server Security**, the server's and each database's (DB0). It opens what Open Security Management opens.
- **Mark (OT1, with the owner's note):** a grey **↗ (arrow.up.right, without the square)** at the right of every row that opens a tab, a window or a sheet (SH0), **always shown** (MS0, owner's pick over on hover). → TREE-6.3

## 2026-10-01 · The blur under the footer: ten small steps instead of a frosted bar

Round 27 (U5), the owner's note on the running app: the blur was "a bar of blur", not smoothing to clear as it goes up. The blur is stacked layers, each a real blur of what is under it, faded in by a mask; a layer that fades in shows a mix of two blurs, and when they differ a lot the mix reads as haze with an edge. It is now **ten small steps from sharp to 12pt**, easing in (level k is 12 × (k/10)^1.5, so the smallest steps are at the top), each adding just enough to reach its level and fading in over one and a half bands so neighbours overlap. The card tint under the footer eases in along the same S curve instead of a straight ramp. Replaces the six near-equal radii of f756a13b and the six 0.75 to 10pt steps before it. → FTR blur, `LayoutTokens.EdgeBlur`

## 2026-10-01 · Round 34 follow-up: no long operation ends silently

Asked in chat ("fix the open points"). A long operation shown on the bell (5 s or more, not cancelled) that posted no notification of its own within 2 s of its end now gets one: "Backup shop finished in 1:12" or "Backup shop failed: reason" (`OperationFinishNotifier`, hooked to `ActivityEngine.onFinish`). Operations that post their own are not doubled. → Echo Labs › Notifications NTF-2.2

## 2026-10-01 · Round 40 accepted: a server click opens the hidden tree

Echo Labs › Window and cards › Clicking a server while the tree is hidden · round 40. Built in 3416c997.

- **A click (RC1):** with the tree hidden, a click on a server **opens the tree, scrolled to that server**, selected in the rail. The owner asked for it ("I hate" the peek).
- **Motion (OM0):** the tree slides in **while** it scrolls to the server, one movement.
- **Arrival (SM1, owner's pick over a flash):** nothing more; the rail's disc shows which server it is.
- **With the tree showing (TV0, owner's pick over a flash):** it scrolls to the card, as before.
- **The peek and its setting are removed** (owner, asked after the round): no glass peek, no ⌘-click to reopen, no Collapsed Server Click setting. Replaces the 2026-09 decision "Server click with the tree hidden: peek, ⌘-click reopens". → WIN-3.5 (WIN-3.3 retired), 05-components › Server rail

## 2026-10-01 · Round 35.1 accepted: the tab overview becomes the ⌘K palette

Echo Labs › Tabs › Tab overview: the direction · round 35.1. Asked: the overview looked hideous. The owner picked TO6 over the recommended TO1 (Safari's grid), and took OR1 and OS0. Follow-up in chat: ⌘K stays the Command Palette; the overview is a feature inside it.

- **Direction (TO6):** no full-window view. The tab overview is **the ⌘K palette turned to this window's tabs**: a "Tab Overview" row in ⌘K, ⇧⌘O, the toolbar's overview button and a pinch open it there. The grouped grid, its pinch-out, and the Tab Overview style setting are removed (owner: "Remove it"). → `05-components` › Tab overview, plan O4
- **For (OR1):** each row shows the tab's state live (Running 0:12, Failed, N rows, Not run), grouped by server.
- **Keys (owner's note):** ⌫ closes the selected tab while nothing is typed (⌘⌫ always), ⌘D duplicates, ⌥⌫ closes the others; the palette stays open. Run/stop from the palette was offered and not taken.
- **Which tabs (OS0):** this window's only.
- Pages 35.2 to 35.4 (card, grouping and order, opening and closing) were written for a full-window overview; see their status in Echo Labs.

## 2026-10-01 · Round 30.1 accepted: the server header in the server's colour

Echo Labs › Explorer tree › Server card: the header · round 30.1, revision 2. The owner's picks where they differ from the recommendation are marked. Built in 5be677fc.

- **Header (HD4, owner's pick over HD10's glow):** a **wash of the colour** at 20% from the card's top edge, fading to clear through the dock; on a closed card it covers the card. **Settings › Appearance › Server Header** also offers **Plain (HD0), Bar (HD12), Glass Plate (HD7) and Banner (HD16)** (owner's list; HS0 with the note "put it where it makes sense", so it sits in Appearance until the Settings round). → TREE-2.6
- **Colour (CS1):** the **server's colour** by default; **Server Header Color** offers None and Accent Color (owner's note). The custom colour (CS3) was dropped in revision 2.
- **Second line (SL0):** product · section, as before.
- **Dock icon (DK1):** the current icon in **the header's colour**, as a setting beside Section Dock Icons (**Current Dock Icon**, owner's note); the accent when the header has none. → TREE-3.2
- **One colour per server (CO2):** with the server's colour, **the rail's monogram is always in it** and **the server's tabs and the footer's server pill carry a 6pt dot of it**. → WIN-2.3, TABS-2.3, FTR-2.4
- **Setting the colour (SC1):** the header's right-click menu › **Color**, with the connection sheet's five swatches; open sessions read the colour live.

## 2026-10-01 · Round 30.3 accepted: the main folders never disappear

Echo Labs › Explorer tree › Database folders that are empty · round 30.3. Built in 5be677fc.

- **Tables, Views, Functions and Procedures always show** (EF1); Synonyms, Sequences, Types and the other rare folders only when they have something. The owner's database really had no views: nothing was lost while loading.
- An empty folder is **dimmed with no count** (EL1) and **opens to a grey “No views” row** (OE0).
- **Settings › Sidebar › Show empty folders is removed** (ST1, owner's pick over keeping it). → TREE-6.2

## 2026-10-01 · Round 34 accepted: Refresh and the activity signal

Echo Labs › Window and cards › Refresh and the activity signal · round 34. Asked: after a query, Run and Refresh both showed ✓. Every recommendation was taken except where marked.

- **Activity (AS2):** Refresh shows **only its own reload**. It no longer mirrors the `ActivityEngine` or the schema loading. **Long operations show on the bell**: a small spinner once one has run for a second, and its name in the bell's tooltip; their notifications say when they end. Query runs stay off the bell (`begin(…, showsOnBell: false)`): Run shows them.
- **Refresh (RL1, owner's pick over RL2):** stays **in the toolbar, only while the front tab can reload** (Activity Monitor, Agent Jobs, Error Log, Extended Events, Structure, maintenance, diagrams, Profiler, Resource Governor, Tuning Advisor, Policy Management). Hidden on query tabs and with no tab.
- **On a query tab (QR1):** nothing; the schema reloads from the tree's menu and after DDL.
- **⌘R (KR0):** View › Reload Tab reloads the front tool tab, through the same reloader as the button, so the button shows it. → `05-components` › Toolbar, plan K6

## 2026-10-01 · After round 31: Run waits 3 s for the time, the zoom pill chases the results, an even blur

The owner's notes on the running app, decided in chat. Built in f756a13b.

- **Run's time after 3 s** (changes round 20's G0, "at once"): ▶ still turns into ■ on red at once; the capsule widens and the time fades in only once the query has run 3 s, so a quick query never grows and shrinks. → EDT-4.3
- **The zoom pill follows the results card:** while the results grow or fold, the pill rides on the editor card's visible edge, a moment behind with a small bounce (`liquidTrail`), instead of vanishing and reappearing in its new place. → EDT-1.4
- **The blur fades evenly** (round 27, U5 note "hard capped"): its steps are now near-equal radii (4 to 5.5pt) with overlapping fades, so the blur grows evenly from sharp to about 12pt at the edge instead of jumping within one row. → FTR blur, `LayoutTokens.EdgeBlur`

## 2026-10-01 · Round 30.2 accepted: a server card folds while its rows fade

Echo Labs › Explorer tree › Server card: collapsing · round 30.2. Every recommendation was taken. Built in 7503bb42.

- **Chevron (CP1):** at the trailing edge, **centred on the name and product line** (it sat level with the name's top). Shown on hover while open, always while closed (CV0, as before); › turning down (CS0, as before). → TREE-2.4
- **Motion (CM2):** the card's **edge glides** on `expand` (0.22s) while the dock and rows **fade and are cut by the edge** and its rounded corners, so nothing floats on the canvas; the cards below follow on the same curve. The card used to snap while its rows faded. → TREE-2.5
- **Closed card (CC0):** the header only, with the owner's note: **the name, product line and chevron centred in the closed card**; they glide between that and their open place. → TREE-2.1, 2.5

## 2026-10-01 · Round 33 accepted: the Agent Jobs tab, finished

Echo Labs › Tool tabs › SQL Server Agent Jobs: the tab · round 33. The Proposal was accepted; the owner's pick where it differs from the recommendation is marked.

- **Headers (JH1):** one **pane header** for Jobs, Details and History: 13pt semibold title, a grey count, the pane's actions at the right, 12pt in, on one 36pt line (`PaneHeader`). Details had been a point bigger and 4pt further in and down.
- **Layout (JL1):** Jobs takes the **full height on the left**; Details sits **over History on the right** (62% / 38%). History stays under the job it describes.
- **Details sections (DT0, owner's pick over DT1):** Properties, Steps, Schedules and Notifications stay **segmented, centred under the header**, as today.
- **Jobs columns (JC1):** **Status, Name, Last Run, Next Run**. One status symbol (ready, running, failed, disabled) replaces Enabled, Status and Last Outcome; Owner and Category are in Properties. A disabled job's name is dimmed and its next run says Disabled.
- **Empty rows (ER1):** no stripes; every list in the tab ends where its rows end.
- **Job actions (JA1):** **New Job and Start/Stop** (for the selected job) on the Jobs header; Enable, Disable, New Alert, New Proxy, Manage Categories and Refresh in ⋯; Start/Stop, Enable and Disable on right-click.
- **A running job (JR1):** a **spinning symbol**, and its **elapsed time counting up in Last Run**, from the Agent's start time; the tab polls while any job runs. → `05-components` › Tool tabs, plan TL4

## 2026-10-01 · Round 31 accepted: the zoom pill sits like the footer's pills

Echo Labs › Editor and running › the zoom pill and the footer · round 31. Every recommendation was taken. Built in 3626716a.

- **With results (ZW1):** the pill sits **12pt in and 9pt up** from the editor card's bottom, where the server pill sits in the results card. It had been 8pt in and 28pt up.
- **Without results (ZN2):** the footer floats in the editor's card, so the pill **stacks above the server pill, left edges aligned, 9pt between** (42pt up). It had landed on the server pill.
- **Height (ZH1):** **24pt**, the footer's chip height (it was about 21pt). **Text (ZT1):** **primary**, as the server pill (it was secondary). → EDT-1.4

## 2026-10-01 · Round 27 refined and accepted again: the bar as wide as the footer, the blur rising past it, everywhere

Echo Labs › Footer and results › round 27, revision 5. The owner loved the first build "about 90%": the bar didn't reach as far as the footer and sat over sharp rows.

- **Length: L2 · as wide as the footer**, from its left padding, over the row numbers, to its right. The grid's width (as first built) was not chosen.
- **Behind it: U5 · the blur rises past the bar while it shows**, with the owner's note that it must animate beautifully and meet the rows naturally rather than at a hard line. Built as: the blur's views keep the raised height and only their masks move, animated by Core Animation (0.32s up, settling 0.9s after the last scroll in 0.5s), and the blur has finer steps (0.75 · 1.5 · 3 · 5 · 7.5 · 10pt, was 1 · 3 · 6 · 10), a 24pt fade (was 16) and an S-curve fade per step. Sharp rows, the blur always that high, a glass lane and a band of the card's colour were not chosen.
- **Gap: H1 · 9pt** and **track: T1 · none**, as built.
- **Everywhere** (owner, after round 27): every overlay horizontal scroll bar in Echo gets the same rising blur, SwiftUI tables included, with nothing to set per view: `ScrollBarBlur`, attached by `ScrollBarBlurHook` after every `NSScrollView.tile()`, installed at launch. → Phase 5 R14

## 2026-10-01 · Round 28 accepted: the find bar, search and replace, the lane, one mark language (28.12 to 28.15)

Echo Labs › Editor and running › Query editor · round 28, pages 28.12 to 28.15. The owner's picks where they differ from the recommendation are marked. Built in ac5089f6 (the gutter's Column and Hairline full height in decd9770).

- **Find bar (28.12):** Echo's own **glass capsule with glass buttons** over the top of the editor (FB5, owner's pick over a system find bar); options in a menu, the count as “3 of 12”; a selected word becomes the search; a selection over several lines gets a **Selection button, on** (SS2 + SS1, owner's note: no button without a selection). → EDT-1.6
- **Search and replace (28.13):** each match shows its replacement **in the text while you type**: the old word struck through on red, the new one after it on green; the script itself does not change until Replace (PV6, owner's pick after the design language). ⌥⌘F or the chevron **opens Replace inside the capsule as it grows** (AN1); ⌘F goes to Find and leaves Replace as it is (FO0); Return replaces and moves on (RK0); Replace All is **one undo** and says “Replaced 12” (RA0, UN0); system shortcuts (SH0). → EDT-1.6
- **The lane (28.14):** the whole gutter (LH0), 5pt from the card's edges, **the card's full height** (LT1), **corners concentric with the card's** (LC1), the system's quiet fill (LF1), **numbers centred** (LA1). → EDT-2.1
- **One mark language (28.15):** every mark on the text comes from `EditorMarkTokens`: **round ends** (DC2, owner's pick over one 3pt corner), **two strengths, soft 10% and strong 22%** (DT1), **colour by meaning**: grey the same word, yellow found, red wrong or removed, green added, accent where you are (DM1); as high as the letters, the selection the whole line (DH0); **Settings › Editor › Marks: Corners and Strength** replace Selection Corners and Highlight Corners (DS1); everything that floats over the code is glass with a coloured symbol and grey words (DF0); tokens, not per-mark values (TK0). → EDT-2.5, 2.7, 2.8, `EditorMarkTokens`

## 2026-10-01 · Round 28 accepted: marks, errors, the run note, zoom, typing, the empty tab, settings (28.5 to 28.11)

Echo Labs › Editor and running › Query editor · round 28. The owner's picks where they differ from the recommendation are marked. Built in 56799682, 306a8fb2, f530ad91, a80770d9, 8464a8c1, 433f34e1, c30bc3e7.

- **Marks (28.5):** the word's other uses in a **soft tint as high as the letters** (H1); **corners 3pt, a setting** (Highlight Corners; owner's pick over following the selection); **typing ) flashes its (** (P1); no glass on the text (GL0); 0.25 s. The find look is decided with the find bar (28.12). → EDT-2.7
- **Errors (28.6):** a **tinted red pill** behind the word (E10, owner's pick after three revisions of glows), the same while typing and after a run (SL0); the message in a **glass popover with a pointer** (BB3, owner's pick), on hover or with the caret on the line (M3); the gutter dot stays; the live check runs **when you leave the line or 2 s after typing** (T1); nothing moves (MO0); “! Error” stays (RN1). → EDT-2.3, 2.8
- **After a run (28.7):** the note on a **glass pill with the result's symbol** (R10, owner's pick), after the last line, **one per statement of a script** (MS0); while running the statement's **bracket breathes** (RR1, rev 3); when it ends a **line beside what ran fades** over 2 s (H9, owner's pick); the count is every row the server sent; it goes at the first edit. → EDT-3.3, 3.5, 3.6
- **Zoom (28.8):** a glass **“100%” pill at the bottom left**, always shown, with a menu (Z1, L2, V0); ⌘+ ⌘− ⌘0 and pinch; per tab, not saved; 50% to 200%; the editor only. → EDT-1.4
- **Typing (28.9):** Go to Line as a **glass field at the top** (GL1); **Tab 4 spaces**, ⇧Tab outdents; **Return keeps the indent**; **( and quotes close themselves**, the closer steps over; **⌘/ toggles --**; wrapping stays, with a switch. Find moved to 28.12. → EDT-1.5
- **Empty tab (28.10):** the prompt **on the first line where you type** (Y1); **prompt only** (EC2, owner's pick: the recent tables and snippets go). Outline edge stays a setting, off; the system's scroll bar. → EDT-1.3
- **Settings (28.11):** **one Settings › Editor pane** (SP0); switches for line numbers, the word highlight and wrapping (HS0); gutter style and statement focus stay; the live check and the error note move there; **only Aurora and Midnight** until themes return (TH1, owner's pick); whole font sizes, “13 pt” (FS1). → Settings › Editor

## 2026-10-01 · Round 28 accepted: the editor's text, gutter, caret line and statement (28.1 to 28.4)

Echo Labs › Editor and running › Query editor · round 28, pages 28.1 to 28.4. Every recommendation was taken except where marked. Built in 9715ce3b.

- **Text (28.1):** a line is **1.55 × the font size** (20pt at 13pt, L2); the Line Spacing setting had been counted twice (31pt). Line Height becomes **Compact (1.3), Comfortable (1.55, the default) or Relaxed (1.75)** (LS1); older values land on the nearest. **SF Mono** is the default font (settings still on JetBrains Mono move to it once); **ligatures off** by default; 13pt stays; the code starts **16pt** after the numbers; **8pt** above the first line. 17pt and 23pt lines, and JetBrains Mono as the default, were not chosen. → EDT-1.2, 05-components › Editor card
- **Gutter (28.2):** SF digits **2pt under the code** (N1) in the **tertiary label** colour (C1); the caret line's number in the **text colour**, same weight (K1; it had been the faintest). Subtle stays the default; **owner's note: every surface is a setting**, so **Hairline** (G3) joins Column and Lane. Error dot and Run arrow keep their own column (M0); wrapped lines stay blank; a click on a number selects the line. → EDT-2.1, 2.2
- **Caret line and selection (28.3):** **no current-line band** (CL1). The **system selection colour** (S1; NSTextView already drew it, the page had said otherwise), **rounded 3pt, the owner's pick over Square**, and a setting: Square, 2, 3, 4 or 6pt. The caret is the **system insertion point** (accent, I1); blinking as the system sets it; grey selection when the editor isn't focused. → EDT-2.4 to 2.6
- **Statement (28.4):** a **bracket beside the statement's line numbers** instead of the band (B1); the **Run arrow grey, accent under the pointer** (A1); only with two or more statements; a selected script result's statement gets the **bracket, solid** (SR1); statements end at a semicolon, GO or a blank line. → EDT-3.1, 3.2
- Also fixed: the run note counts every row the server sent (18b2898d; round 28.7 asks the rest). → Phase 20

## 2026-10-01 · Round 27 accepted: the scroll bars over the footer

Echo Labs › Footer and results › Results scroll bars and the footer · round 27. Echo gave the grid's and the editor's scroll views the footer's room twice (content inset and scroller inset, which AppKit adds), so the horizontal bar floated over the rows a footer's height above the footer.

- **Where: E · on the footer's top edge**, with the owner's note: the bar keeps the same gap above the pills as the pills keep above the card's edge (9pt), so it never sits flush with them (`LayoutTokens.Footer.scrollBarBottom`, 42pt to the thumb's bottom). A, B, C, D, F and G were not chosen.
- **Look: S1 · the system's bar.** The thin line, soft capsule, accent, glass track and groove were not chosen.
- **When: V1 · while scrolling**, as macOS does. Always, near the bottom and over the grid were not chosen.
- **Vertical bar: R2 · runs down to the horizontal bar.** Stopping above the footer and no vertical bar were not chosen.
- **Extra: X1 · soft edges where more columns wait** (`ScrollSideFades`, 32pt). A line on the footer's edge, a column map and a line under the header were not chosen.
- **Scope: every scroll bar in a card.** Built for everything that scrolls under the footer: the results grid and the editor (`FooterScrollOverlay`), the Messages console and Extended Events data (`footerScrollRoom`). Tool tabs without a footer keep the system's bar at the card's bottom edge; giving them the same spacing is a follow-up.
- Building it moved the footer's blur into the scroll view's clip view, under the bars, so a bar over the footer isn't blurred; the editor's blur, which sat inside its scroll view and blurred nothing, now works. → Phase 5 R13

## 2026-10-01 · Round 25 accepted: SQL Server imports with the bulk load

Echo Labs › Explorer tree › SQL Server: importing a file · round 25. sqlserver-nio sends imports with the TDS bulk load (as bcp and SqlBulkCopy); the Import Data sheet offers its options.

- **Options: IO1 · an Options section, every option visible** (SQL Server only): Empty cells, Keep identity values (was Identity Insert under Target), Check constraints, Fire triggers, Lock the table, with a line saying what locking costs. A disclosure (IO2) and today's Identity Insert alone (IO3) were not chosen.
- **Empty cells: EC1 · a choice in the sheet, NULL by default** (NULL or the column default). Always NULL (today) and always the default were not chosen.
- **A failed import: FA1 · undo everything, one transaction.** The sheet says "Nothing was imported. dbo.orders is as it was." with the server's error under it; a cancel says nothing was imported. Keeping the rows already imported (FA2) was not chosen.
- **Batch size: BS1 · 10,000 rows** for SQL Server (other engines keep 1,000). 1,000 and the whole file in one batch were not chosen.
- **INSERT statements: ME1 · said only when they were used** (a table with geometry, sql_variant, text and similar columns). Always naming the method and never naming it were not chosen.
- Built as reviewed: progress moves per batch, "Imported 48,210 rows in 1.9 s", footer Done or Failed. → Phase 18 S7 (`Features/Import/BulkImport*`)

## 2026-10-01 · Smoothness pass: the owner's answers

After the overnight tracing pass (commits f90524d9 to 9819269c), asked in chat:

- **A plain tab switch moves the highlight at once.** Only a tool tab unfolding or folding its pages springs (`QueryTabStrip.unfoldAnimation`, keyed on the unfolded tab). → Echo Labs › Tabs (TABS-5.2)
- **Live dates tick only while their tab is on screen** ("updated 5 s ago" in a tool's header, Last Run, last vacuum); in a tab kept mounted behind another they are frozen (`SinceDateText`). → Echo Labs › Tool tabs (header text)
- **Activity Monitor while the tree or inspector slides:** to be judged in a Lab round (hold the content's width during the slide, or reflow live at ~20 fps).
- **Move the Explorer into a shared package** so Echo Labs renders the real tree: next.
- Recorded as built, to confirm in the running app: six tabs stay loaded (was three); the window can't be dragged while a window or Explorer animation runs; a section switch fades a card-coloured veil in (0.12 s), moves the card's edge (0.28 s) and fades it out (0.22 s), where round 19 recorded 0.08 s and 0.18 s fades. → Echo Labs › Tabs, Window, Explorer tree

## 2026-09-30 · Round 23 accepted: PostgreSQL connection sheet for companies

Echo Labs › Connections › round 23 (three pages), for what postgres-wire now supports: Kerberos, encrypted client keys, several servers with failover.

- **Kerberos sign-in: KP1 · a Mechanism menu, Password or Kerberos** (as SQL Server's sign-in, CON-3.2); **KN1** it is called Kerberos; **KT1** under Username a line says whose ticket signs in and until when, or that there is none or it expired, with Open Ticket Viewer; **KS1** the Kerberos Service row sits in Security and timeouts, only for Kerberos (empty is postgres); **KU1** choosing Kerberos with no user name fills in the ticket's name without the realm. Test without a ticket: **NT1** "No Kerberos ticket" with Open Ticket Viewer. The server asks for a password instead: **KF1** fail with "The server asks for a password, not Kerberos" and a Use Password button. A Password connection to a Kerberos server: **PK1** the ticket is used, as with libpq. → CON-3.1, CON-3.2, CON-4.3, CON-6.2
- **Encrypted client key: KW1** the Key Password row appears only when the chosen key (or .p12 file) is protected by a password; **KK1** it is kept in the Keychain like the password; **KL1** it is called Key Password; **KR1** the certificate rows get labels on the left, the file name and Choose… on the right (the path on hover); **KE1** a wrong key password shows under the row and in the result line; **PF2** .p12/.pfx files are accepted: one file fills both certificate rows, unlocked by the key password. → CON-4.3, CON-6.2
- **Several servers and failover: FH1** "+ Add Server" adds a row per server under Server; **FT1** Connect To in plain words (Any Server, Primary, Standby, Standby or Any if None Is Up; a pasted URL's read-write and read-only are kept); **FW1** Connect To appears under the servers once there are two; **FL1** load balancing is not in the sheet (a pasted URL can set it); **FS1** after a failover the footer shows a chip with the server (db2 · primary, where it moved from on hover) and a notification says so; **TS1** Test checks every server, one line each, and says where Echo would connect; **FR1** a query tab whose server went away shows Connection lost as round 21 decided, and Reconnect goes to the new server; **PU1** a pasted postgres://db1,db2/app URL fills a row per server and Connect To. → CON-2.3, CON-4.1, CON-6.2

## 2026-09-30 · Round 24 accepted: ▶ into ■

Echo Labs › Editor and running › Run: ▶ into ■ · round 24, on the owner's notes on round 20 (R1, R2 and R4 had "exactly the animation I want"; R0 and R3 did not). Replaces round 20's open item and its A2 glass morph.

- **One button, never swapped.** Run draws its own glass (the toolbar item's shared glass is hidden) and draws the red itself (Y), so the plain ▶ never gives way to the system's prominent button sliding in. → 05-components › Toolbar, EDT-4.3
- **Morph: M1 · ▶ is replaced by ■ in place** (SF Symbols' replace), as in round 20's R1. The shape morphs (corners slide, turn and square), magic replace, draw off and on, and squeeze were not chosen.
- **Red: F1 · the glass fades to red** while ▶ turns into ■. The flood, plain glass (F3) and the swap were not chosen.
- **Time: W1 · the capsule grows, then the time fades in,** once there is room. Sliding out, rolling digits and no time were not chosen.
- **Curve: K2 · staged:** icon and colour first (0.25 s), then the width; no overshoot (`settle`). The house spring and unstaged smooth were not chosen.
- **Ending: B0 · the red drains and the capsule shrinks as the ✓ draws.** Shrink first and reverse morph were not chosen.

## 2026-09-30 · Round 20: the Run button

Echo Labs › Editor and running › Run button: look (accepted) and Run button: running (answered; the change into running goes to a new round).

- **At rest, unchanged:** F0 plain ▶ (play.fill) in its own capsule, label colour, accent with a selection, nothing on hover, other modes on right-click and in the Query menu, always Run (no last mode). Hidden on other tabs (O0). No extra press echo for ⌘↩ (D0). → 05-components › Toolbar, EDT-4.1, 4.2, 4.5
- **When it can't run: U1 · dimmed, the tooltip says why** ("Type a query to run"). → EDT-4.1
- **Tooltip: T1 · where it runs:** "Run in employees on Prod SQL (⌘↩)", "Run Selection in …". → EDT-4.1
- **Narrow window: V1 · Run never goes into »;** its neighbours go first (toolbar visibility priority, macOS 26.1).
- **⌘↩ toggles Run and Stop** (owner's note on W2): pressed while a query runs, it stops it, like clicking ■. The Query menu's Run item reads Stop Query meanwhile. ⌥⌘. still cancels too.
- **Running, unchanged:** R0 red prominent capsule, ■ and the timer, at once (G0), still (P0), ■ stop.fill (X0). Nothing on Run for a query in another tab (B0); a cancel goes straight back to ▶ (Z0); no batch progress (Q0); every run, however started, shows the same running look (Y0).
- **Timer: K1 · “5 s”, then “1:05”.** → EDT-4.3
- **Result: E1 · the ✓ draws itself** (SF Symbols' Draw On), held 2.4 s (T1). → EDT-4.4
- **A slow cancel: J1 · Stopping:** the capsule dims, ■ becomes a small spinner and the words say Stopping; it can't be clicked. → EDT-4.3
- **Long query while away: N1 · a macOS notification** for a query of 30 s or more that ends while Echo isn't in front ("Query 1 finished in 2:14"). → 05-components › Notifications
- **The change into running** went to round 24 (above): the owner wanted ▶ to transform into ■ and the capsule to grow much more smoothly for the timer; the glass morph (A2) was picked but "not really keen".

## 2026-09-30 · Round 21 accepted: query time limits

Echo Labs › Connections › Postgres: statement timeouts · round 21 (revision 2). Chosen on the "Where the message goes" exhibit.

- **Where: TW2 · a default in Settings › Databases, which a connection can override** (its Query Time Limit; empty uses the default, 0 is none). Per tab is `SET statement_timeout` in the tab. → 05-components › Connections, Results card
- **Default: TD2 · no limit unless set.** No Echo limit leaves the server's own (for the role or database) in force.
- **When it fires: TF4 · explained where the result would be, plus a notification when you're elsewhere** (another tab or app): "Stopped after 30 s: the statement limit for this connection.", Run Without Limit, and the settings it came from.
- **Lock waits: TL4 · no lock field; show the wait instead,** and **LF3 · the footer's status says Waiting for lock, with who holds it on hover** (checked once a second after 2 s, on another connection).
- **The saved 60 s: M3 · reset to no limit**, told once. Echo has no What's New screen, so it is a one-time notification (kept in history) the first time a query runs.
- **The limit in the footer: FT1 · 0:12 / 0:30 while running.**
- **A limit set on the server: SL1 · named**: "Stopped by the server's limit of 30 s (set for your role or database)."
- **Idle in transaction: IT1 · not offered.** **Scripts: SC1 · each statement** (PostgreSQL's own behaviour).

## 2026-09-30 · Round 21 accepted: an open transaction on close

Echo Labs › Tabs › Postgres: open transaction on close · round 21.

- **Form: G2 · an alert,** like "Save changes?". **Default button: D1 · Commit** (Roll Back is the destructive choice, Cancel stops). → 05-components › Tabs
- **Detail: DT2 · the sentence, how long it has been open and how many statements ran** ("Query 1 has a transaction on shop that is not committed. Open for 12 minutes · 3 statements."). The driver counts statements since BEGIN.
- **When: W1 · closing the tab, switching database, disconnecting, quitting.**
- **Failed transaction: FT1 · Roll Back and Cancel,** saying it failed ("Nothing can be committed").
- **Quitting: Q1 · one alert listing the tabs:** Review…, Roll Back All, Cancel. Disconnecting a server with several such tabs asks the same way.
- **Don't ask again: N1 · no.**
- The state is checked with the server before asking (transaction state K1).

## 2026-09-30 · Round 21 accepted: PostgreSQL transaction state

Echo Labs › Footer and results › Postgres: transaction state · round 21. The owner judged it on the gallery of all states.

- **Where: TS3 · the footer's status pill.** The tab itself is not marked (TS4, recommended, was not chosen). → 05-components › Results card, FTR-2.6
- **Look: TL2 · icon and word:** Transaction with a branch icon; Failed — roll back with an octagon. → FTR-2.6
- **Colour: TC1 · orange, red when failed.**
- **Time: TT2 · after a minute** the pill shows how long the transaction has been open ("Transaction 2:14").
- **Actions: TA2 · Commit and Roll Back in the pill's menu,** with Show in Messages; a failed transaction offers only Roll Back.
- **Failed: F1 · red, "Failed — roll back".**
- **Long transaction: R3 · a notification after 15 minutes** with nothing run inside an open transaction (recommended was R2, the pill turning red).
- **How the state is known: K1 · from the statements** (no extra round trip); the close prompt checks the server (with the open-transaction round).

## 2026-09-30 · Round 21 accepted: cancelling a query

Echo Labs › Editor and running › Postgres: cancelling a query · round 21. Applies to SQL Server too (round 22, CL1).

- **While stopping: CX3 · in the footer.** The status says **Cancelling**, pulsing, with no dots (owner's note): the verb matches Cancel Query and the Cancelled result, SSMS says the same, and the footer's other states (Executing, Connecting) have no dots either. How Run itself looks while stopping stays with the Run button round. → 05-components › Results card
- **Rows already fetched: CP1 · kept, marked as partial:** the footer's count reads "1 200 rows, partial". → 05-components
- **Server doesn't stop: CS2 · Force Stop after 5 s:** a banner in the results, "The server hasn't stopped the query.", with Force Stop, which closes the connection (an open transaction is rolled back; the next run uses a new session). → 05-components
- **Reported: CR2 · the run note at the statement and Messages:** "Cancelled after 3.2 s · 1 200 rows", in orange. → 05-components, EDT-3.3
- **Shortcut: K2 · ⌥⌘. only;** ⌘. stays EchoSense (owner's note).
- **Inside a transaction: TX1:** the note adds "The transaction now needs ROLLBACK", with a line in Messages.

## 2026-09-30 · Round 21 accepted: PostgreSQL script results

Echo Labs › Footer and results › Postgres: script results · round 21.

- **Layout: SR4 · a statement list at the left** of the results, the selected statement's result beside it. Batch tabs (today), tabs named by statement (recommended), stacked sections and one timeline were not chosen. → 05-components › Results card
- **Label: SL3 · the statement's first words** ("SELECT … FROM customers", "UPDATE orders SET"). → 05-components
- **Commands: SC2 · entries with their tag** ("INSERT 0 2") in the list, in order with the results. → 05-components
- **Messages: SP2 · one line per statement** ("3 · UPDATE 3 · 12 ms"); no started/completed lines. → 05-components
- **Link: SK2 · the selected result lights its statement** in the editor, until the text changes. → 05-components, EDT-3.1
- **A failed statement: E3 · stop by default,** "Stopped: statement 4 failed; statement 5 was not run."; Settings › Databases › PostgreSQL › Continue after a failed statement runs the rest. → 05-components
- **All or nothing: OT1 · Run as One Transaction** in the Run button's menu and the Query menu, off by default, per tab: BEGIN before the script, COMMIT after it, ROLLBACK when a statement fails; a script with its own BEGIN or COMMIT runs as written. → 05-components

## 2026-09-30 · Round 21 accepted: a PostgreSQL connection lost

Echo Labs › Notifications › Postgres: connection lost · round 21.

- **Where: CL1 · the error in Messages, and a notification** through the notification engine (owner's note). The banner on the editor (recommended), the footer and the run note were not chosen. → 05-components › Notifications
- **When: CW2 · the moment it drops,** before any run. → 05-components
- **Reconnect: RC2 · a Reconnect button** on the notification and its history row. Reconnecting is a new session (SET, temporary tables and the lost transaction are gone); runs are refused until you press it. Reconnecting on the next run and reconnecting at once were not chosen. → 05-components
- **Wording: WD2 · what it means for your work:** the transaction was rolled back and nothing since BEGIN was saved; the technical cause follows. → 05-components
- **Nothing open: I1 · quietly:** the footer says Disconnected and the next run reconnects (recorded in history without a toast).
- **After reconnecting: RR3 · never offer Run again.**
- **History: H1 · yes,** the drop is recorded.

## 2026-09-30 · Round 22 accepted: SQL Server values, errors, and cancel and sessions

Echo Labs › round 22 (three pages). sqlserver-nio now formats values exactly, reports structured errors and cancels on the server; Echo follows.

- **Values in the grid (Footer and results): DF1** SQL Server style dates (`2026-09-30 12:34:56.123`, the column's own precision); **DO1** datetimeoffset as stored with its offset; **MN1** money and smallmoney always with four decimals; **GE1** geography longitude first, as STAsText; **SS1** every spooled row (preview included) stored as wire bytes and formatted by the driver's `SQLServerCellFormatter`, so rows after 200 read like the preview. ISO dates, converted offsets, trimmed money and the mixed spool were not chosen. → 05-components › Results card, FTR-2.3
- **Errors and messages (Editor and running): EM1** the SSMS line `Msg 547, Level 16, State 0, Line 3` over the message; **LL1** "Line 3" selects that line in the editor; **AM1** every message of the batch in the order the server sent it, PRINT output included; **CU1** a COMMIT with an unknown outcome says "The connection was lost during COMMIT. The transaction may or may not have been saved; check the data before running it again."; **FE1** severity 20 and above is handled as a lost connection, with the server's message; **ED1** the in-editor mark follows the Postgres error-location decision. → EDT-3.3, FTR-2.3
- **Cancel, timeouts and lost connections (Editor and running): TO1** the query time limit follows the Postgres timeouts decision (TW2 Settings default with connection overrides, TD2 no limit unless set) and is the driver's request deadline; the hard-coded 45 s goes. **CL1** cancelling looks exactly as the Postgres cancel page decides; a cancel keeps the session. **XA1** tabs keep XACT_ABORT ON, and a cancel inside a transaction says "Transaction rolled back". **LC4 (owner's choice in chat, replaces LC1): a dropped connection follows the Postgres decision (CW2, RC2, WD2)** — Echo says at once what was lost (temporary tables, SET options, open transaction) and offers Reconnect; nothing reconnects or reruns by itself, for both engines. **BG1** ship the background changes: shared threads for tabs, APP_NAME() "Echo", extra result sets spooled instead of held in memory, one task at a time per tab session, pooled sidebar sessions reset and reused. → EDT-3.3, EDT-4.3/4.4, FTR-2.6, CON-4.5

## 2026-09-30 · Round 22 accepted: SQL Server encryption settings

Echo Labs › Connections › SQL Server: encryption settings · round 22. With sqlserver-nio's hardening, no mode sends credentials unencrypted any more; the sheet now says what each mode checks.

- **Default: ED1 · Mandatory for new connections** (encrypts and checks the certificate, as ODBC 18, JDBC and SSMS 20 do). Saved connections keep their mode. Optional (today's default) was not chosen. → 05-components › Connections, CON-4.2
- **Menu words: EW1 · Say what is checked:** "Optional – encrypt, don't check the certificate", "Mandatory – encrypt and check the certificate", "Strict – TLS first (TDS 8.0), always checks"; the info text says every mode encrypts the password and the session. SSMS's bare words were not chosen. → CON-4.2
- **Strict and Trust: ST1:** under Strict the Trust Server Certificate switch turns off and dims, with a note that Strict always checks. → CON-4.2
- **SQL Server 2008 R2 without its TLS 1.2 update: LT2 · an "Allow TLS 1.0" switch** for that connection, off by default and not available under Strict. Recommended was LT1 (require TLS 1.2). The driver refuses TLS 1.0/1.1 unless the switch is on and explains a server that only offers them. → CON-4.2
- **Test failures: TE1:** the result says which certificate check failed (untrusted issuer, self-signed, expired, not yet valid, another host name) and offers the fix: **Trust this certificate** (turns on Trust Server Certificate) or, for another host name, **Use Host Name In Certificate** filled with the certificate's name. → CON-6.2

## 2026-09-30 · Round 21 accepted: values in the grid

Echo Labs › Footer and results › Postgres: values in the grid · round 21. Drawing only: copy, export and the inspector keep the server's text.

- **Arrays: VA4 · Count, then the first items:** `3  new, gift, express`, the count in secondary text. The server form, a plain list and chips were not chosen. → 05-components › Results card
- **JSON: VJ3 · Summary:** `{ 4 keys }`, `[ 12 items ]`; the full value opens in the inspector. Recommended was VJ2 (one line with key colour). → 05-components
- **Binary: VB3 · Kind and size:** `PNG image · 12 KB`, `Binary · 20 bytes`. → 05-components
- **Numbers: VN2 · Aligned on the decimal point,** without digit grouping. → 05-components
- **Copy: CP3.** ⌘C copies the server's text; **Copy as Shown** in the menu copies what is drawn. → 05-components
- **Empty text and NULL: EN1** (today): NULL in grey, an empty string shows nothing.
- **Ranges, intervals and infinity: SP1** keep the server's form.
- **Other databases: SC1** by kind: JSON, binary and numbers are drawn the same for SQL Server and MySQL; arrays exist only in PostgreSQL.

## 2026-09-30 · Round 19 accepted: the section dock

Echo Labs › Explorer tree › Section dock (three pages), on the owner's feedback about round 16 as built. Replaces the round 16 rules below where they differ.

- **Switching: S3 · Fade through.** The card's rows fade out quickly, swap, and fade in while the card's bottom edge settles (`settle`). Nothing slides in from the bottom. S0 (today), S1 card crossfade, S2 swap and settle, S4 slide and S5 instant were not chosen. → 05-components › Explorer tree, TREE-3.7
- **Where the view goes: jump to where the section was left,** instantly, while the rows are faded; a section never seen before doesn't scroll. The animated glide goes. → TREE-3.7
- **The other cards: N2.** A card animates only when its own place or height changes, and the view never scrolls back by itself when the list gets shorter: the room below the last card stays until you scroll up. Fixes the card above animating. → TREE-1.2
- **Capsule: C5 · Glass with an edge:** Liquid Glass with a hairline edge and a soft shadow. **Medium** icon weight, today's sizes. The current section stays **accent colour only** (the pill was recommended but not chosen). **Hover: the icon grows.** Other styles (tinted, frosted, filled track, raised pill, glass pill, bar, floating, underline) were not chosen. → TREE-3.1 to 3.3
- **Section name under the server's name:** "SQL Server 2022 · Security". → TREE-2.2
- **SQL Server: G1 · SSMS five:** Databases (Database Snapshots at the end), Security, **Server Objects** (Linked Servers, Server Triggers), Agent Jobs, Management (with Integration Services Catalogs). G0 (eight) and G2 were not chosen. The section is named **Server Objects**. → blueprints
- **Five at most:** the capsule shows up to five sections, and **no database type's blueprint has more than five** server-level sections; new tools go inside a section. → blueprints, TREE-3.5
- **Sections that don't fit: M2 · More as a section:** » is a section whose card lists the left-out sections as ordinary folders, which open and right-click as usual. The » menu, submenus, scrolling, shrinking and a second row were not chosen. → TREE-3.4

## 2026-09-30 · Round 16 accepted: the server card

Echo Labs › Explorer tree › Server card · round 16 (owner's bugs and feedback on the section dock as built).

- **Header H5 · Glass capsule:** Xcode's navigator icons spread across a Liquid Glass capsule as wide as the card, the current one in the accent colour with no fill. The capsule is a control, not the card, so "cards are never glass" still holds. H0 (today's tiles), H1 navigator bar, H2 segmented, H3 one line, H4 section menu and H6 labelled current were not chosen. → 05-components › Explorer tree
- **Pinned: name and icons,** because several servers share the column. Icons only was not chosen.
- **Version under the name,** as the product and release ("SQL Server 2022", "PostgreSQL 18.3"); the full build is in the tooltip. Replaces the full build on the right. → 05-components
- **Under the header: Blur rows,** modelled on the system's soft scroll edge. Rows stay under the pinned header and blur and fade more towards the top, over a light wash of the card colour. It works with stacked cards, which the real system edge can't. Replaces the grey material. Fade rows, the hairline and the system edge (one server per column) were not chosen. → 05-components
- **Switching sections: crossfade,** with the card's height settling without overshoot (`settle`). Rows no longer drop in from the top. Slide and instant were not chosen. → 05-components, 04-motion
- **Initial load: I4 · Folders first.** A section's folders and tools show at once (the blueprint knows them), each spinning in its count slot; a level that is only items (databases, jobs) shows one spinner row. The dock icon stays still. Replaces the shimmer for sections. I1–I3 and I5 were not chosen. → 05-components
- **Opening a folder: quiet skeleton,** row-shaped placeholders shown only after a quarter second. Replaces the shimmer. → 05-components
- **Counts always show,** quiet grey, in the whole tree. Replaces S4 Quiet's "counts appear on hover". → 05-components
- **Selection is inset equally on both sides** (the 8pt pull to the left, left over from S1's chevron column, goes). → 05-components
- **The dock follows the sidebar size setting.** → 05-components
- **Right-click a dock icon** for its section's own menu, then Dock (show or hide each section, the type's defaults, Customize Dock). Sections left out sit under More (»). **Customize Dock** sets the order and visibility for every server of the type (saved in Settings › Sidebar, synced with the settings) or one server (saved on the connection). The dock's icon style (mono by default) is its own setting, apart from the tree's. → 05-components
- **PostgreSQL's dock:** Databases, Security, Activity (Activity Monitor's pages), Management (Maintenance, Back Up Server, Back Up Globals, Restore, PSQL Console) and Tablespaces. → blueprints
- **No dock under two sections** (SQLite shows its name and tree; MySQL gets two icons). → 05-components

## 2026-09-30 · Round 18: the notification toast

- **L2 · Title and detail:** a bold title (the message up to its first ": ") with the reason under it in two lines of secondary text; hovering shows the whole reason, selectable. One line, the pill and the server line were not chosen. → 05-components › Notifications
- **A2 · Small buttons:** Open Tab or Show Server, Copy and Show All, as in the history. → 05-components › Notifications
- **D3 · Swipe right** dismisses (past 80pt; a short drag springs back); × still shows on hover and always on errors. → 05-components › Notifications
- **Unchanged:** Liquid Glass, dropping in from the top (arrival confirmed in chat), a list of three, 3 s; errors stay until dismissed. Tinted glass, an opaque card, the deck, newest-only and 5 s or 8 s were not chosen.

## 2026-09-30 · Round 17 accepted: the notification history

- **D · Compact cards,** grouped by time (Today, Yesterday, then the date), opening with a fade: one line per event (icon, the message's first part, time); opened, the server, the rest of the message (selectable) and the actions. B · Cards was a maybe; A · Timeline, C · List and detail, E · Attention first and F · Stacked by server were not chosen. → 05-components › Notifications
- **Header H3:** the count of what was new sits quietly beside the title; filters and Clear All share one ⋯ menu. The accent "2 new" and Clear looked odd. → 05-components › Notifications
- **Actions A2:** Open Tab (or Show Server) and Copy are small native bordered buttons. → 05-components › Notifications
- **Unread:** bold plus the count is enough; no dots.

## 2026-09-30 · Round 15 answers

- **Run: idea 1, quiet glyph,** in its own toolbar capsule so it doesn't push the other icons. Ideas 2–5 (footer, editor corner, tab, only while running) rejected. → 05-components › Toolbar
- **Inspector: grouped boxes** in one card. One card with hairlines and separate cards rejected. → 05-components › Inspector
- **Notification history: B, the inspector's column.** Unfold from the stack (A) and a notifications tab (C) rejected; the bell popover is gone. → 05-components › Notifications
- **Toasts below the tab bar,** and on a query tab inside the editor card's top-right corner, so they don't cross its edges. Customising the corner comes later. → 05-components › Notifications
- **Search:** no toolbar field; the magnifier and ⌥⌘F open ⌘K. → 05-components › Search

## 2026-09-30 · Design board and round 14 answers

Design board: https://claude.ai/artifact/8gQM8VJCknMvFRsCTTSnHJ (collections `verdicts`, `topics`, `notes`). Round 14 answered in the Design Lab.

- **Tree card: TC1 section dock.** An icon row (Databases, Security, Agent, Management, More) under the server name switches what the card shows; icons only. It stays pinned while the rows scroll under it, with **only a soft blur**: no background, no line. Each section remembers its scroll position and open folders. Every other layout (TC2–TC9) was rejected. → 05-components › Explorer tree, plan Phase 16
- **Tree icons: IC2 duotone** is the default, IC1 mono line stays a setting. Tiles, letters and dots rejected. A Recraft icon set is pinned for later; SF Symbols drawn duotone until then. → 05-components › Explorer tree
- **Tool tabs:** TT1 panes become cards, TT2 one shared tool header (icon, title, server and freshness, actions), TT3 dashboard tiles for monitoring tools. Configuration stays in the tab; job history may use the Inspector. TT4 rejected. → 05-components › Tool tabs, plan Phase 15
- **Tool pages open with ST2: the tool's tab unfolds** and shows its pages inside itself. Replaces TT6 and the segmented control at the top of tool tabs. ST1, ST3, ST4, ST5 rejected. → 05-components › Tabs
- **Tab bar: back to Round 9's strip** (grey plate, white active tab), **on one line**. Every tab keeps its kind's icon; the database moves to the tooltip. Replaces round 11/12's glass capsule with two lines, which the owner regrets. N1, N1R, N4–N9 and R9R rejected. → 05-components › Tabs, plan Phase 14
- **Connections:** CN2, one short sheet for Quick Connect (saving off) and New Connection; **editing happens inside Manage Connections** (CN5). CN1, CN3, CN4 rejected. Rules CR1 (buttons never silently disabled; inline messages), CR2 (port follows the engine), CR3 (paste a URL anywhere), CR4 (test result by the buttons), CR5 (Quick Connect never asks for a name), CR7 (Advanced remembers itself). CR6 rejected: **Quick Connect also saves its password in the Keychain**. → 05-components › Connections, plan Phase 13
- **Editor fonts:** bundle JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Monaspace and Commit Mono; remove the other eleven. The owner picks the default later. **13pt with 1.55 line spacing**, both settings. → 05-components › Editor card, plan Phase 11
- **Gutter:** numbers stop at the last line (GL1). The tinted style becomes two settings: **column** (GT1, full height, cut by the card's corners) and **lane** (GT2, inset rounded). Subtle stays. GT3, GT4 rejected. → 05-components › Editor card
- **Editor ideas, all accepted:** statement focus with a Run arrow (QE1), results inline (QE2), errors on the line (QE3), room to breathe (QE4), outline edge as a setting (QE5), a helpful empty tab (QE6). → plan Phase 17
- **EchoSense:** ES1 rows (kind badge, name in the editor font with typed letters highlighted, alias, type), ES4 details in a footer with rounded, concentric corners, ES3 ghost text as a **setting, off by default**. ESR1–ESR3 and ESR6; **ESR4 tint while typing, solid once choosing**; **ESR5 card material, corners follow Card Corners** (capped so rows stay concentric). ES2, ES5 rejected. → 05-components › EchoSense, plan Phase 12

## 2026-09-29 · Tree card revised to S4 Quiet with folders

The owner revised the tree card choice to **S4 Quiet**, with the Design Lab's **Folders** and **Dimmed prefix** controls. The card stays the same. At medium density, ordinary rows are 28pt in a 29pt slot, with 13pt labels, 13pt light monochrome-rendered symbols, an 8pt icon-to-label gap, 16pt indentation and 8pt corners. There is no separate disclosure column: a folder's icon becomes a 10pt semibold chevron on hover. Folder counts appear on hover. Selection returns to the semantic grey fill; selected icons remain accented. Server-level groups return to ordinary folders and their children regain one indent level. The bold server name and version, Vivid icon palette and ordered blueprints remain. Supersedes the S1 and Sections choices below. → 05-components, 06-tokens

## 2026-09-29 · Phase 6–9 answers

- **Cancel Query is ⌥⌘.**; EchoSense keeps ⌘. → 05-components, plan K1
- **The tab overview button** leads the right-hand capsule: [Overview · Refresh · Bell · Inspector]. → 05-components
- **Query shortcuts kept:** Run Statement at Cursor ⇧⌘↩, Explain ⌥⌘E, Explain Analyze ⌥⇧⌘E, Validate ⇧⌘B, Search ⌥⌘F, Command Palette ⌘K. → 05-components
- **Statement at cursor** ends at a semicolon, a `GO` line or a blank line (blank lines split, even inside a procedure body). → 05-components

## 2026-09-29 · EchoSense keeps ⌘.

The owner: EchoSense must be triggered by ⌘., which is muscle memory; users can pick another shortcut. This reverses K3's "EchoSense off ⌘." and clashes with "Cancel on ⌘.". Cancel is ⌥⌘. until the owner picks its shortcut. Open. → 05-components, plan K1, K3

## 2026-09-29 · The database switcher becomes a system popover

The owner found the status popover's Liquid Glass perfect and the switcher's in-window glass flatter and whiter (glass drawn inside the window samples only the card behind it and has no window shadow). Rather than an AppKit panel to mimic a popover without its arrow, the owner chose SwiftUI's own `.popover`, accepting the arrow, "and not fight it, as it will cause different theming issues". The card keeps its filter, list and keyboard; the popover handles closing. Replaces L2/A2. → 05-components › Results card, Floating cards

## 2026-09-29 · Round 11 corrected: T1 with two-line tabs and icons

The owner meant **T1 (Safari)**, not T2, together with T7's two lines, and from round 12 **L2's icon**; no more lab rounds for the tab bar. The glass tab bar: inactive tabs have no fill, full-strength titles and hairline dividers; the active tab is a raised white pill; every tab shows its kind's icon (a spinner while running) and two lines, the title over the database (the timer while running). The bar is 10pt taller. Classic stays as the fallback. Supersedes the T2 entry below. → 05-components

## 2026-09-29 · Tree card answers: S1 Tahoe, sections, blueprints

Design Lab page "Tree card · contents" (owner's answers, pasted in chat):
- **Tree style: S1 Tahoe.** 26pt rows in a 27pt slot (medium), 13pt labels, 13pt hierarchical symbols in both icon modes, 9pt bold chevrons in the quaternary grey, 7pt between chevron, icon and label, 14pt indent, 8pt row corners, the selection tinted with the row's accent (18%, 30% with Increase Contrast) instead of grey, and the server's name in bold 13pt primary with its product and version on the right. Replaces the grey selection pill, the 12pt indent and the 11pt grey server name. → 05-components, 06-tokens
- **Icons: colourful by default, Vivid palette** (today's colours softened 22%). Monochrome stays a setting. → 05-components
- **Schema names: the dimmed prefix stays.** → 05-components
- **Server folders are sections:** Databases, Security, Agent Jobs and the other server-level folders are Finder-style headings (11pt semibold grey, count, a trailing chevron shown while collapsed or hovered), and their children start at the card's left edge. MySQL's and SQLite's server tools move under a Management heading so they don't read as databases. → 05-components
- **Tree blueprints: accepted.** Each database type's tree becomes an ordered blueprint with node kinds and roles, replacing the switch statements. Plan Phase 2b. Explainer: https://claude.ai/artifact/N7UL1qHMGicpthQmSKVa89

## 2026-09-29 · Tree card contents opened

The owner likes the server card itself but finds the content inside it dated. Design Lab page "Tree card · contents" shows six styles beside today's (S1 Tahoe, S2 Tiles, S3 Structure, S4 Quiet, S5 Detailed, S6 Path), each in colourful and monochrome, with shared controls for the palette (Vivid, Soft, Families, Server colour), schema names and server folders as sections. The card's surface, corners, edge and shadow are not in question. It also proposes describing each database type's tree as an ordered blueprint (explainer: https://claude.ai/artifact/N7UL1qHMGicpthQmSKVa89). Open.

## 2026-09-29 · Round 11 answer: T2 filled tabs; two-line tabs to explore

Design Lab round 11 (owner's answer, pasted in chat): **T2, filled tabs** inside the glass capsule, so inactive tabs read as buttons with near-full-strength text. "I like the idea of T7 with two lines. Let's explore that as well" → round 12 in the Design Lab explores two-line versions of T2. Also: the results must fold back into the footer smoothly; it now runs as one continuous path (the editor card grows back to full height while the results card lands on its bottom edge and its chrome fades out). → 05-components

## 2026-09-29 · Round 11 opened: the tab bar again

After living with TB1, the owner finds the glass capsule weaker than the old strip ("the tabs not used is too light"). Round 11 in the Design Lab lays out eight designs (T1 Safari, T2 filled tabs, T3 separate pills, T4 server colour, T5 hugging, T6 underline, T7 two-line, T8 accent active) beside today's glass and Classic. Fixed meanwhile: results always fold back into the footer; the status pill sits at the far right.

## 2026-09-29 · Round 10 review page answers

Page: https://claude.ai/artifact/BfUjeUCPDv9rd6cDXzCwEA (collection `round10`)
- **Results entrance: RS2, the results grow up out of the footer** ("I want it to look like it is the footer that is expanding up"). Rejected RS1 (split in place) and RS3 (crossfade). → 05-components, 04-motion
- **Pinned path header: P1, removed**, with its blur and its setting. Rejected P2 (only with one server), P3 (blur only), P4 (keep it, off by default). → 05-components
- **Inspector: IN1, a column of cards on the canvas**, mirroring the tree. Rejected IN2 (floating card), IN3 (inside the results card), IN4 (native, restyled). Phase 9 is rewritten around it. → 05-components, plan Phase 9

## 2026-09-29 · Round 10, Design Lab answers

Lab page "Round 10 · footer and switcher" (owner's answers, pasted in chat):
- **Footer right-hand side: a glass pill per entry** (status, selection summary, rows, time), the same size as the server · database chip. `FooterMetricsStyle.pillPerEntry` is the default. → 05-components
- **Database switcher: L2, a card floating above the chip**, which stays visible; no chip label inside the card. → 05-components
- **Opening: A2, the card rises** a little while fading in, with the house spring. It replaces the frame morph. → 04-motion, 05-components

## 2026-09-29 · Round 9 decided in the Design Lab

Lab page "Round 9 · open questions" (owner's answers, pasted in chat):
- **Behind the footer: FB1, soft blur** (`BackdropEdgeBlur` over the AppKit grid and editor). Follow-up asked: show the right-hand data (status, rows, time) as one big pill or a pill per entry; that goes to round 10. → 05-components
- **Footer position: FP1**, lifted 4pt from today. → 05-components, 06-tokens
- **Tree scroll bar: SB3, none**, with a setting to show it, off by default ("Show Scroll Bar" in Settings › Sidebar). → 05-components
- **Tab bar: TB1, one glass capsule with + inside.** The owner isn't fully sold, so the old strip stays in the code as "Classic", switchable in Settings › Appearance, to revert to. → 05-components
- New asks for round 10: the results card's entrance should split the editor card rather than rise from the bottom; a view on removing the pinned path header; an Inspector phase; and the database switcher's card and animation judged in the Design Lab (it should open as a glass card from the pill).

## 2026-09-29 · Scroll bar, database switcher, footer and tabs (review round 9, first answers)

Page: https://claude.ai/artifact/U3DDrkf5zQUEq6635UVBaY (collection `round9`)
- **Database switcher DB1:** clicking the footer chip grows it upward into a glass list with a filter field at the top, no arrow; Esc or a click outside shrinks it back. It replaces the system popover. Rejected DB2 (native menu) and DB4 (pick it in the tree). → 05-components
- **DB3 as well, not instead:** "Switch database" also joins the ⌘K palette in Phase 6 ("This is not a replacement but an alternative"). → plan K4
- **Faster tab switching (TFIX):** tabs become real buttons, so a click selects at once and dragging still reorders; recently used tabs keep their editors alive, so switching back keeps scroll, undo and cursor. → 05-components, plan B5
- Rejected: SB2 (a scroll bar inside each card), SB4 (position shown in the rail), FP2 (footer inset by the corner radius), TB2 (tabs on the canvas), FB3 (a glass footer bar with glass pills inside it: glass on glass).
- **Still open, to judge in the Design Lab:** scroll bar SB1 or SB3; footer position FP1 or FP3; tab bar TB1, TB3 or TB4; and what sits behind the footer, FB1, FB2 or FB4 (section 5, added after the owner found the solid band behind the footer ugly: soft edge, hard edge, or one glass bar with flat controls inside).

## 2026-09-29 · After the SwiftUI tree build (asked in chat)

- Bug: the tree's cards layer set the tree's minimum height, so the window grew with the tree and couldn't be shrunk. The cards now draw in the scroll view's background.
- **Hiding the tree no longer overshoots:** it uses a spring with no bounce (`settle`), and showing it keeps the bounce. The rail-edge mask is gone because it cut the tree card's shadow. → 04-motion
- **Footer:** the result views pill sits right beside the server/database chip instead of in the middle. → 05-components

## 2026-09-29 · Corners and tree motion (review round 8, first answers)

Page: https://claude.ai/artifact/XPy7hr8a2BgpXjejFSxUWA
- **Card corners 16pt by default** (C3), the macOS 27 window corner as measured from the owner's screenshot (about 16pt; my first guess of a 26pt window and 20pt cards was wrong). A Card Corners setting in Appearance offers 10 / 12 / 16 / 20 / 26pt for every card. → 02-layout, 06-tokens
- **Hiding the tree keeps the bounce, walled off** (M1): everything right of the rail is masked at the rail's edge. **The tree slides left behind the rail** as it fades (M2's motion) instead of shrinking. → 04-motion
- Answered on the page (collection `round8`):
  - **The Explorer tree is rebuilt fully in SwiftUI, replacing the AppKit table, with no debug switch** ("more future proof"). That settles tree cards as T1 (each server card is the editor's own `.workspaceCard()`) and the path header as H1 (a pinned glass section header that blurs the rows). → 05-components, `swiftui-tree.md`
  - **Welcome W1b:** one centred column on the canvas: Echo's icon, "Echo" large, the glass actions, the recents card. No subtitle. Rejected W1a and W1c. → 05-components
  - **Server page S1a:** the server name large, only the version under it, the glass tools, then a databases card with a filter; its top lines up with the rail. Recent queries and connection details leave the page. Rejected S1b and S1c. → 05-components
  - **Footer FT1a:** no strip or divider; the server and database as a glass chip (no chevron; click to switch database), the result views in one glass pill, and the status, rows and time as quiet text. Rejected FT1b, FT1c and FT1d. → 05-components

## 2026-09-29 · Tree cards, scrolling and the bottom edge (review rounds 5–7)

Pages: round 5 https://claude.ai/artifact/CZU1FEeERxgrgLLYttJJ1U · round 6 https://claude.ai/artifact/3VqbnxEy4z1ThCnQJt64Ta · round 7 https://claude.ai/artifact/D77uNvnAc3AzGzic7k88PW and https://claude.ai/artifact/RMNCE8fCR7X367ydcyUjZk
- **Tree cards use exactly the editor card's tokens** (fill, edge, `workspaceCard` shadow, 12pt corners). The lighter shadow and the lifted card from round 4 are gone. The tree follows the existing settings: Spacing Between Panes sets the gap between cards, the Explorer size setting sets the rows. No new card settings. → 05-components, 06-tokens
- **Glass card header** (round 6, option 2): once a server's own header scrolls away, "server › database" pins at the top of its card on Liquid Glass with the card's rounded top corners; rows blur through it. It holds controls, so glass is allowed. Replaces the blurred path bar. Rejected: opaque sticky top (1), scrolling under the toolbar (3), a blur band (4). → 05-components, 03-materials
- **Rounded end** (round 7, F2): the tree stops one gutter above the window edge, on the editor card's bottom line; a card that runs past the bottom is cut into rounded corners with the full card shadow. No fade anywhere. Rejected: glass footer (F1), next-server tab (F3), filter bar (F4). → 05-components
- Fixed as bugs: the first card lines up with the rail and tab plate; connecting and failed servers come last in rail order, each on its own card; the scroller is the small overlay scroller inset inside the card corners; the sidebar toolbar button has its own glass. → 05-components

## 2026-09-29 · Tree cards and server page (review round 4)

Review page: https://claude.ai/artifact/2A6mzm6CNJTKnWt8FwLETg
- **Each server's tree sits on its own opaque card** (option B, "Server groups"). The card has the editor card's fill, a lighter shadow, and 12pt corners; the server at the top of the tree, which the rail selects, lifts with a slightly stronger shadow. The first card lines up with the top of the rail. Replaces "the tree has no panel or background of its own". → 02-layout, 05-components, 06-tokens
- **Opaque, not glass.** The owner asked; the reasons: the tree is content, glass over the flat canvas has nothing to refract and reads as a grey box, and glass trees would compete with the glass rail. "Glass only on controls" stands. → 03-materials
- Rejected: one full-height tree card (A), staying on the canvas with lines and a tint (C), glass per server.
- **Server page in the welcome's style:** on the canvas with no big card; icon, name, host and version; the tools on Liquid Glass buttons with New Query prominent; "New query in", "Recent queries" and "Connection" as small opaque cards with 28pt rows, two columns when there is room. → 05-components

## 2026-09-29 · Empty window (asked in chat)

After the owner opened Echo with nothing connected:
- **The tree only shows when it has content:** a server in the rail (connected or connecting) or a tool page from the bottom pill. With neither it is hidden and ⌃⌘S and the toolbar button do nothing. → 02-layout
- **Welcome on the canvas, no card.** Cards are only for content. With no tab and no active server the canvas shows Echo's icon, "Connect to a server", glass buttons (Connect… prominent with the connections menu, Quick Connect, Manage), and the 5 latest connections on one small opaque card, each row with its rail monogram in the server's colour, name, host and when it was last used. Tiles and a search-first welcome were offered and not chosen. → 05-components
- **Sidebar button in the toolbar** at the leading end (`sidebar.left`), as on every Mac app with a sidebar. Fixed as a bug: ⌃⌘S now reaches Echo, because the system's sidebar menu item is replaced.

## 2026-09-29 · First build of the shell (asked in chat)

After the owner ran Phase 1:
- **+ back in the rail**, as the last item of the server pill. It opens the connections menu and replaces the toolbar's Connections button (Recent and Quick Connect stay in the toolbar). Reason: with one server the pill held a single item and read as a double border; connecting from the rail is also closer to the servers. Replaces "no + in the rail" from round 1. → 02-layout, 05-components
- **Selection disc inset 3pt** inside its item, so it never echoes the pill's edge. → 06-tokens, 05-components
- **Tools stay a vertical pill** at the bottom of the rail, the same width as the server pill. Horizontal under the tree, one combined pill and toolbar tools were offered and not chosen. → 02-layout
- Fixed as bugs, no rule change: the start page lists the 5 latest connections; content can never push the window past its edges; the rail, tree and tab plate sit one gutter below the toolbar and the plate lines up with the card; the pinned path blur is tinted to the canvas and fades at every edge.

## 2026-09-29 · Last open questions (asked in chat)

Decided:
- Stronger connecting pulse confirmed. → 06-tokens, 05-components, 04-motion
- Rail status: running queries show nothing in the rail; a lost connection dims the monogram to 40%, with the reason in its tooltip. → 05-components
- Toolbar grouped by task; tab-specific tools in one contextual capsule next to Run. → 05-components
- Run gets a chevron menu of run modes. → 05-components
- No floating editor capsule. → 05-components
- Double-click the gap to maximise the results. → 05-components
- Autocomplete keeps its system popover, the one exception to arrowless cards; no panel windows planned. → 03-materials, 05-components

With this, nothing in the design is left Open.

## 2026-09-29 · Review round 3 (Design Lab), second part

The remaining 11 questions.

Decided:
- Rail selection: liquid stretch (glass lens rejected, so "no glass on glass" is now fully decided). → 05-components, 04-motion, 01-principles, 03-materials
- Selected monogram in its server's colour. Pill growth and the translucent canvas accepted. → 05-components, 06-tokens
- Connecting pulse was too subtle: stronger values proposed, to confirm in the Design Lab. → 06-tokens
- Results: name + type header with a sort arrow on hover; row hover tint with an accent row number; one-outline selection; footer with rows loaded of total and a selection summary; monospaced cells setting. → 05-components
- One footer only, in the results card, holding both the connection picker and the results data. The window-wide status bar goes away. → 05-components

## 2026-09-29 · Review round 3 (Design Lab), first part

17 of 28 questions answered in the Design Lab. The server rail and results grid pages couldn't be judged because the playgrounds slid under the lab's page list; that is fixed, and those 11 questions are still open.

Decided:
- Card corners 12pt, replacing the earlier "concentric with the window" rule. → 02-layout, 06-tokens
- Floating card shadow. Gutter 6pt, adjustable in settings (4/6/8). → 02-layout, 06-tokens, 01-principles
- Hiding the tree: the tree shrinks into the rail. → 02-layout, 04-motion
- Server click with the tree hidden: peek, ⌘-click reopens; adjustable in settings. → 05-components, 01-principles
- Tab strip on the canvas above the cards. Results card rising accepted. → 02-layout, 05-components
- Tree: bold server header; pinned header with breadcrumb accepted; monochrome mode defaults to accent on open folders, with pure monochrome as a setting; soft colourful mode accepted. → 05-components
- Toasts: stacking, expanding on hover, ×2/×3 repeats and the history card growing out of the bell all accepted. → 05-components
- Inspector: proposed design and smooth width change accepted. → 05-components

Still open (to judge in the Design Lab): rail selection style, selected monogram colour, connecting pulse, pill growth, rail on the translucent canvas; results column header, row hover, selection outline, footer content, where the connection bar lives, monospaced cells setting.

## 2026-09-29 · Review round 2 (deep dives)

Decided:
- Motion: bouncy by default; speed setting Default / Fast (Slow rejected). → 04-motion
- Glass morphing everywhere it explains change: new server from the pill, peek card from its server, toolbar groups, stacked toasts, new tab from +. → 04-motion
- Rail: server pill hugs its servers and scrolls once full. Connecting servers breathe. → 05-components
- Tree: expand with a slide and fade; loading with shimmer rows; the server header is the sticky header, with a breadcrumb. → 05-components
- Search: minimised toolbar search plus ⌘K palette; finds objects, tabs, actions and history. → 05-components
- Tabs: Safari as the reference; keep today's grey plate, tokenised; switching is instant; running shows spinner + timer; many tabs collapse inactive ones to icons. → 05-components
- Tab overview is the "open queries" view: toolbar button + pinch; calm cards with live state; zoom motion. → 05-components
- Run is the one tinted toolbar item (accent, red while running). Echo keeps control of toolbar grouping. → 05-components
- Editor actions stay in the toolbar. Gutter: subtle or tinted as a setting, with validation markers. Results card rises after the first run; drag the gap to resize. → 05-components
- Results: right-aligned numbers, boolean symbols, monospaced setting, one outline per selected range, accent row numbers, no footer Export, NULL stays as text. → 05-components
- Notifications: stacked and expandable glass toasts; history under a toolbar bell; query errors in the results card plus a toast for background tabs. → 05-components
- Floating cards: in-window glass, no arrow, close on outside click or Esc, no pin. → 03-materials, 05-components
- Inspector: native; one section style, smooth width, row-detail mode. → 05-components

Left open after round 2 (see round 3 for what was settled): card corners, shadow and gutter; rail selection and monogram colour; tree-hide motion; server click with the tree hidden; tree header style and monochrome variant; results header, hover, footer; where the connection bar lives; tab strip position; inspector look; toolbar group layout.

## 2026-09-28 · Review round 1 (143 options)

Decided:
- Canvas and cards layout replaces the system sidebar. → 02-layout
- System grey canvas by default, translucent as the alternative, graphite dark mode. → 02-layout
- Rail: Liquid Glass, two pills, medium size with a setting, monograms, system tooltip, highlight follows scroll, no + in the rail. → 02-layout, 05-components
- Tree hidden: the rail stays identical and the cards slide over the tree. → 02-layout, 04-motion
- Tree: grey selection, plain counts, breadcrumb sticky header, density levels stay. → 05-components
- Toolbar: glass groups. Editor and results as two cards, results footer kept. Inspector stays native. → 02-layout, 05-components

Rejected: glass cards for content, flush panes without gutters, white canvas, one combined rail pill, tools under the tree, a + at the top of the rail, colour dots and engine badges on servers, ring and comet status indicators, a search field at the top of the tree.

## 2026-09-28 · Direction chosen

The "Canvas and cards" direction, inspired by Outlook's Mac layout: rail pill at the leading edge, tree on the window canvas, content in floating cards. It replaced the adaptive server rail inside the system sidebar, which read as loose buttons with the tree lost in the middle.
