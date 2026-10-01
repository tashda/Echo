import SwiftUI

/// The timeouts playground: where the limit is set (left) and a query tab that runs past it (right).
/// Revision 2: nothing about limits shows in the tab unless a limit is set; a blocked query can
/// say it is waiting for a lock.
struct PgTimeoutExhibit: View {
    typealias R = PgTimeoutsRound
    let where_: R.Where
    let default_: R.Default
    let fired: R.Fired
    let locks: R.Locks
    let lockStatus: R.LockStatus
    let appliesLimit: Bool

    @State private var elapsed: Int?
    @State private var stopped: PgTimeoutReason?
    @State private var blocked = false
    @State private var tabOverride: Int??
    @State private var withoutLimit = false
    @State private var hoveringStatus = false
    /// "Set Limits" simulates typing 30 s (statement) and 5 s (lock) into the connection's fields.
    @State private var typedLimits = false
    @Environment(\.echoMotion) private var motion

    private var connectionLimit: Int? {
        if typedLimits { return 30 }
        switch default_ {
        case .sixty: return 60
        case .five: return 300
        case .off: return nil
        }
    }

    private var lockLimit: Int? { typedLimits && locks == .field ? 5 : nil }

    private var limit: Int? {
        guard appliesLimit, !withoutLimit else { return nil }
        if let tabOverride { return tabOverride }
        return connectionLimit
    }

    private var limitScope: String {
        if tabOverride != nil { return "the limit for this tab" }
        if where_ == .settings, !typedLimits { return "your default limit in Settings" }
        return "the statement limit for this connection"
    }

    private var waitingForLock: Bool { blocked && stopped == nil && (elapsed ?? 0) >= 2 && lockStatus != .none }

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            PgTimeoutSettingsColumn(where_: where_, locks: locks, appliesLimit: appliesLimit,
                                    connectionLimit: connectionLimit, lockLimit: lockLimit, typedLimits: typedLimits)
                .frame(width: 230)
            VStack(spacing: SpacingTokens.xs) {
                PgEditorCard(lines: blocked ? ["alter table orders", "  add column note text;"]
                                            : ["select customer_id, sum(total)", "from orders_2019_2026", "group by 1;"])
                ZStack(alignment: .topTrailing) {
                    results
                    if let stopped, fired.toastHere { PgTimeoutToast(reason: stopped) }
                }
                PgSimBar(actions: [("Set Limits", { typedLimits = true }), ("▶ Run", { run(blocked: false) }),
                                   ("Wait on a Lock", { run(blocked: true) }), ("+10 s", { tick() }), ("Reset", { reset() })])
            }
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .animation(motion.standard, value: stopped)
        .animation(motion.hover, value: hoveringStatus)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if let stopped {
                if fired == .footer {
                    Text(PgTimeoutMessage(fired: fired, reason: stopped).messagesText).foregroundStyle(ColorTokens.Text.secondary)
                } else {
                    PgTimeoutMessage(fired: fired, reason: stopped) {
                        if !stopped.isLock { tabOverride = nil; withoutLimit = true }
                        run(blocked: false)
                    }
                }
            } else if let elapsed {
                Text(blocked ? "Running… (another session holds a lock on orders)" : "Running… \(elapsed) s")
                    .foregroundStyle(ColorTokens.Text.secondary)
            } else {
                Text("Run the query.").foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer(minLength: SpacingTokens.none)
            PgFooter(segment: stopped != nil && fired == .footer ? "Messages" : "Results") {
                if where_ == .connectionAndTab || where_ == .tabOnly { tabMenu }
                statusPill
                timerPill
            }
        }
        .font(TypographyTokens.detail)
        .padding(SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    @ViewBuilder
    private var statusPill: some View {
        if stopped != nil {
            PgPill(tint: ColorTokens.Status.error) {
                PgStatusLabel(text: fired == .footer ? "Timed out" : "Error", color: ColorTokens.Status.error)
            }
        } else if waitingForLock {
            PgPill(tint: ColorTokens.Status.warning) {
                Image(systemName: "lock")
                Text("Waiting for lock")
            }
            .onHover { hoveringStatus = $0 && lockStatus == .pillWho }
            .overlay(alignment: .bottom) {
                if hoveringStatus { lockHolderCard.offset(y: -SpacingTokens.xl).fixedSize() }
            }
        } else if elapsed != nil {
            PgPill { PgStatusLabel(text: "Running", color: ColorTokens.Status.info) }
        }
    }

    private var lockHolderCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.nano) {
            Text("Blocked by anna · pid 4412").font(TypographyTokens.labelBold)
            Text("UPDATE orders SET status = 'paid' …").font(TypographyTokens.detailMono)
            Text("In a transaction for 3 min").foregroundStyle(ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.detail)
        .padding(SpacingTokens.xs)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium))
    }

    @ViewBuilder
    private var timerPill: some View {
        if let elapsed {
            PgPill {
                if let limit, stopped == nil {
                    Text("\(pgDuration(elapsed)) / \(pgDuration(limit))").monospacedDigit()
                } else {
                    Text(pgDuration(elapsed)).monospacedDigit()
                }
            }
        }
    }

    private var tabMenu: some View {
        Menu {
            Button("Connection's limit (\(pgLimitText(connectionLimit)))") { tabOverride = nil }
            Button("No limit for this tab") { tabOverride = .some(nil) }
            Button("5 minutes for this tab") { tabOverride = .some(300) }
        } label: {
            Image(systemName: "timer")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Query limit for this tab")
    }

    private func run(blocked: Bool) {
        self.blocked = blocked
        elapsed = 0
        stopped = nil
        if blocked { withoutLimit = false }
    }

    private func tick() {
        guard let current = elapsed, stopped == nil else { return }
        let next = current + 10
        let lockSeconds = blocked ? (locks == .same ? limit : lockLimit) : nil
        if let lockSeconds, next >= lockSeconds {
            elapsed = lockSeconds
            stopped = locks == .same ? .statement(seconds: lockSeconds, scope: limitScope) : .lock(seconds: lockSeconds)
        } else if let limit, next >= limit {
            elapsed = limit
            stopped = .statement(seconds: limit, scope: limitScope)
        } else {
            elapsed = next
        }
    }

    private func reset() {
        elapsed = nil; stopped = nil; blocked = false; tabOverride = nil; withoutLimit = false; typedLimits = false
    }
}

/// Where the limits are set: the connection sheet, and Settings for TW2.
struct PgTimeoutSettingsColumn: View {
    let where_: PgTimeoutsRound.Where
    let locks: PgTimeoutsRound.Locks
    let appliesLimit: Bool
    let connectionLimit: Int?
    let lockLimit: Int?
    let typedLimits: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            if where_ == .settings {
                group("Settings › Queries") {
                    row("Statement limit", "No limit")
                    if locks == .field { row("Lock wait limit", "No limit") }
                }
                group("Connection › Security and timeouts") {
                    row("Connection timeout", "30 seconds")
                    row("Statement limit", typedLimits ? "30 s" : "Use default")
                    if locks == .field { row("Lock wait limit", typedLimits ? "5 s" : "Use default") }
                }
            } else {
                group(where_ == .tabOnly ? "Connection (no limit here)" : "Connection › Security and timeouts") {
                    row("Connection Timeout", "30 seconds")
                    if where_ != .tabOnly {
                        row("Query Timeout", appliesLimit ? pgLimitText(connectionLimit) : "60 seconds")
                        if locks == .field { row("Lock Wait Limit", pgLimitText(lockLimit)) }
                    }
                }
            }
            if !appliesLimit {
                Label("Saved and synced, but no query uses it.", systemImage: "exclamationmark.triangle")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.labelBold).foregroundStyle(ColorTokens.Text.secondary)
            content()
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .workspaceCard()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(TypographyTokens.formLabel)
            Spacer()
            Text(value).font(TypographyTokens.formValue).foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}
