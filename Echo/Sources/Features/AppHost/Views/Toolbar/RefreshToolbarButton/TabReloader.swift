import Foundation
import Observation

/// Reloads the front tab's data (round 34). The toolbar's Refresh and ⌘R both go through it, so
/// the button shows the reload whichever started it. It reports only its own reload (AS2): other
/// operations show on the bell.
@MainActor @Observable
final class TabReloader {
    enum Phase: Equatable {
        case idle
        case refreshing
        case completed
        case failed
    }

    private(set) var phase: Phase = .idle
    /// The tab the phase belongs to; any other tab shows Refresh at rest.
    private(set) var tabID: UUID?
    private(set) var message = "Reloaded"

    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    @ObservationIgnored private var resetTask: Task<Void, Never>?

    /// RL1: only these tabs offer Refresh. A query tab doesn't (QR1): its schema reloads from the
    /// tree's menu and after DDL.
    nonisolated static func canReload(_ kind: WorkspaceTab.Kind) -> Bool {
        switch kind {
        case .maintenance, .mssqlMaintenance, .activityMonitor, .errorLog, .extendedEvents, .structure,
             .jobQueue, .diagram, .profiler, .resourceGovernor, .tuningAdvisor, .policyManagement:
            true
        default:
            false
        }
    }

    func phase(for tab: WorkspaceTab?) -> Phase {
        guard let tab, tab.id == tabID else { return .idle }
        return phase
    }

    func reload(_ tab: WorkspaceTab, environmentState: EnvironmentState) {
        guard Self.canReload(tab.kind) else { return }
        reloadTask?.cancel()
        resetTask?.cancel()
        tabID = tab.id
        phase = .refreshing
        reloadTask = Task(name: "Reload \(tab.title)") { [weak self] in
            let failure = await Self.performReload(of: tab, environmentState: environmentState)
            guard !Task.isCancelled else { return }
            self?.finish(failure: failure)
        }
    }

    func cancel() {
        reloadTask?.cancel()
        reloadTask = nil
        resetTask?.cancel()
        phase = .idle
    }

    private func finish(failure: String?) {
        reloadTask = nil
        message = failure ?? "Reloaded"
        phase = failure == nil ? .completed : .failed
        let hold: Duration = failure == nil ? .seconds(1.2) : .seconds(2)
        resetTask = Task(name: "Refresh result") { [weak self] in
            try? await Task.sleep(for: hold)
            guard !Task.isCancelled else { return }
            self?.phase = .idle
        }
    }
}
