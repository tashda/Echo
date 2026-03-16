import SwiftUI
import PostgresWire

// MARK: - Sticky Lock State

/// Merges transient lock snapshots into stable, sticky rows.
/// Locks that disappear are kept as "Released" for a decay period before removal.
@Observable
final class StickyLockState {
    private(set) var displayLocks: [StickyLock] = []
    private let decaySeconds: TimeInterval = 20

    struct StickyLock: Identifiable {
        let key: String
        let pid: Int32
        let locktype: String
        let relation: String?
        let mode: String
        var granted: Bool
        var blockingPid: Int32?
        var query: String?
        var state: String?
        var waitDuration: TimeInterval?
        var databaseName: String?
        var isActive: Bool
        var lastSeenAt: Date

        var id: String { key }

        static func compositeKey(pid: Int32, locktype: String, relation: String?, mode: String) -> String {
            "\(pid):\(locktype):\(relation ?? ""):\(mode)"
        }
    }

    func update(with locks: [PostgresLockInfo], at timestamp: Date) {
        let activeLockKeys = Set(locks.map {
            StickyLock.compositeKey(pid: $0.pid, locktype: $0.locktype, relation: $0.relation, mode: $0.mode)
        })

        // Update existing or add new
        var updatedKeys = Set<String>()
        for lock in locks {
            let key = StickyLock.compositeKey(pid: lock.pid, locktype: lock.locktype, relation: lock.relation, mode: lock.mode)
            updatedKeys.insert(key)

            if let index = displayLocks.firstIndex(where: { $0.key == key }) {
                displayLocks[index].granted = lock.granted
                displayLocks[index].blockingPid = lock.blockingPid
                displayLocks[index].query = lock.query
                displayLocks[index].state = lock.state
                displayLocks[index].waitDuration = lock.waitDuration
                displayLocks[index].isActive = true
                displayLocks[index].lastSeenAt = timestamp
            } else {
                displayLocks.append(StickyLock(
                    key: key,
                    pid: lock.pid,
                    locktype: lock.locktype,
                    relation: lock.relation,
                    mode: lock.mode,
                    granted: lock.granted,
                    blockingPid: lock.blockingPid,
                    query: lock.query,
                    state: lock.state,
                    waitDuration: lock.waitDuration,
                    databaseName: lock.databaseName,
                    isActive: true,
                    lastSeenAt: timestamp
                ))
            }
        }

        // Mark disappeared locks as released
        for index in displayLocks.indices {
            if !activeLockKeys.contains(displayLocks[index].key) && displayLocks[index].isActive {
                displayLocks[index].isActive = false
                displayLocks[index].lastSeenAt = timestamp
            }
        }

        // Remove decayed locks
        displayLocks.removeAll { !$0.isActive && timestamp.timeIntervalSince($0.lastSeenAt) > decaySeconds }

        // Sort: waiting first, then active granted, then released
        displayLocks.sort { a, b in
            let aWeight = !a.granted ? 0 : (a.isActive ? 1 : 2)
            let bWeight = !b.granted ? 0 : (b.isActive ? 1 : 2)
            if aWeight != bWeight { return aWeight < bWeight }
            return a.pid < b.pid
        }
    }
}

// MARK: - Locks View

struct PostgresActivityLocks: View {
    let locks: [PostgresLockInfo]
    let snapshotTime: Date
    @Binding var sortOrder: [KeyPathComparator<PostgresLockInfo>]
    @Binding var selection: Set<StickyLockState.StickyLock.ID>
    let onPopout: (String) -> Void
    var onDoubleClick: (() -> Void)?

    @State private var stickyState = StickyLockState()

    var body: some View {
        Table(stickyState.displayLocks, selection: $selection) {
            TableColumn("PID") {
                Text("\($0.pid)")
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle($0.isActive ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }.width(min: 50, max: 70)

            TableColumn("Type") {
                Text($0.locktype)
                    .font(TypographyTokens.detail)
                    .foregroundStyle($0.isActive ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }.width(min: 80, ideal: 100)

            TableColumn("Relation") {
                Text($0.relation ?? "\u{2014}")
                    .font(TypographyTokens.detail)
                    .foregroundStyle($0.isActive ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
            }.width(min: 100, ideal: 140)

            TableColumn("Mode") {
                Text($0.mode)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(lockModeColor($0))
            }.width(min: 120, ideal: 160)

            TableColumn("Status") {
                LockStatusBadge(lock: $0)
            }.width(80)

            TableColumn("Blocked By") {
                if let blocker = $0.blockingPid {
                    Text("\(blocker)")
                        .font(TypographyTokens.detail.monospacedDigit())
                        .foregroundStyle(ColorTokens.Status.error)
                } else {
                    Text("\u{2014}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                }
            }.width(min: 70, max: 90)

            TableColumn("Wait") {
                if let duration = $0.waitDuration, !$0.granted, $0.isActive {
                    Text(formatWait(duration))
                        .font(TypographyTokens.detail.monospacedDigit())
                        .foregroundStyle(duration > 10 ? ColorTokens.Status.error : ColorTokens.Status.warning)
                }
            }.width(min: 60, ideal: 80)

            TableColumn("Query") {
                if let sql = $0.query, !sql.isEmpty {
                    SQLQueryCell(sql: sql, onPopout: onPopout)
                        .foregroundStyle($0.isActive ? ColorTokens.Text.primary : ColorTokens.Text.tertiary)
                }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: StickyLockState.StickyLock.ID.self) { _ in
        } primaryAction: { _ in
            onDoubleClick?()
        }
        .overlay {
            if stickyState.displayLocks.isEmpty {
                ContentUnavailableView {
                    Label("No Active Locks", systemImage: "lock.open")
                } description: {
                    Text("No lock contention detected")
                }
            }
        }
        .onChange(of: snapshotTime) { _, newTime in
            stickyState.update(with: locks, at: newTime)
        }
        .onAppear {
            stickyState.update(with: locks, at: snapshotTime)
        }
    }

    private func lockModeColor(_ lock: StickyLockState.StickyLock) -> Color {
        guard lock.isActive else { return ColorTokens.Text.tertiary }
        if lock.mode.contains("Exclusive") && !lock.mode.contains("Share") {
            return ColorTokens.Status.warning
        }
        return ColorTokens.Text.primary
    }

    private func formatWait(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return "<1s" }
        if seconds < 60 { return "\(Int(seconds))s" }
        return "\(Int(seconds / 60))m \(Int(seconds.truncatingRemainder(dividingBy: 60)))s"
    }
}

// MARK: - Lock Status Badge

private struct LockStatusBadge: View {
    let lock: StickyLockState.StickyLock

    private var text: String {
        if !lock.isActive { return "Released" }
        return lock.granted ? "Granted" : "Waiting"
    }

    private var color: Color {
        if !lock.isActive { return ColorTokens.Text.quaternary }
        return lock.granted ? ColorTokens.Status.success : ColorTokens.Status.error
    }

    var body: some View {
        Text(text)
            .font(TypographyTokens.compact.weight(.bold))
            .padding(.horizontal, SpacingTokens.xxs2)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}
