import SwiftUI
import HatchCore
import HatchSync

/// The one object every screen reads. It wraps the store (the only place state changes, decision S3), re-publishes after every
/// change, and holds navigation and panel state. Screens never write SQL; they call store methods inside `perform`.
@MainActor
final class AppState: ObservableObject {
    let store: HatchStore
    let paths: AppPaths

    @Published var route: Route = .desk
    @Published var selectedProjectKey: String?          // nil means "All projects" (decision B2, B3)
    @Published var selectedTicketId: Int?
    @Published var revision = 0                          // bumped after any change so views reload
    @Published var errorMessage: String?
    @Published var showAskPanel = false
    @Published var showPalette = false
    @Published var searchText = ""
    @Published var syncSummary = SyncSummary()

    struct SyncSummary: Equatable {
        var pending = 0
        var failed = 0
        var lastOK: Date?
        var message: String?
    }

    init(store: HatchStore, paths: AppPaths) {
        self.store = store
        self.paths = paths
        refreshSyncSummary()
    }

    static func live() -> AppState {
        let paths = AppPaths.default
        do {
            let store = try HatchStore(path: paths.database.path)
            return AppState(store: store, paths: paths)
        } catch {
            // The app must still open so the owner sees the message; fall back to a throwaway in-memory store.
            let store = try! HatchStore.inMemory()
            let state = AppState(store: store, paths: paths)
            state.errorMessage = "Could not open the Hatch database: \(error)"
            return state
        }
    }

    // MARK: Data helpers used by many screens

    var projects: [Project] { (try? store.projects()) ?? [] }

    var selectedProject: Project? {
        guard let key = selectedProjectKey else { return nil }
        return projects.first { $0.key == key }
    }

    /// Project filter for queries: nil when "All projects" is selected.
    var projectFilterId: Int? { selectedProject?.id }

    func project(id: Int) -> Project? { projects.first { $0.id == id } }

    /// Tickets waiting for the owner, for the Dock badge and the sidebar (decision B6).
    var yourTurnCount: Int { ((try? store.countByTurn(projectId: projectFilterId)) ?? [:])[.you] ?? 0 }

    // MARK: Changing things

    /// Runs a store change, refreshes every view, and turns an error into a message the owner can read.
    @discardableResult
    func perform<T>(_ label: String = "", _ work: () throws -> T) -> T? {
        do {
            let result = try work()
            refresh()
            return result
        } catch {
            errorMessage = label.isEmpty ? "\(error)" : "\(label): \(error)"
            return nil
        }
    }

    func refresh() {
        revision += 1
        refreshSyncSummary()
        NSApp?.dockTile.badgeLabel = yourTurnCount > 0 ? String(yourTurnCount) : nil
    }

    func refreshSyncSummary() {
        let counts = (try? store.syncCounts()) ?? (0, 0)
        syncSummary.pending = counts.pending
        syncSummary.failed = counts.failed
    }

    func open(_ ticket: Ticket) {
        selectedTicketId = ticket.id
        route = .ticket(ticket.id)
    }
}

/// Where Hatch keeps its files (database, token, caches). Overridable with HATCH_HOME for tests and the CLI.
struct AppPaths {
    let root: URL
    var database: URL { root.appendingPathComponent("hatch.sqlite") }
    var workspaces: URL { root.appendingPathComponent("workspaces", isDirectory: true) }

    static var `default`: AppPaths {
        if let override = ProcessInfo.processInfo.environment["HATCH_HOME"] { return AppPaths(root: URL(fileURLWithPath: override)) }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return AppPaths(root: base.appendingPathComponent("Hatch", isDirectory: true))
    }
}
