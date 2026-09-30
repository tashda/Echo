import Observation
import SwiftUI

/// The notifications specimen's state, copied from Echo's StatusToastPresenter and
/// NotificationHistory (commit 755f8254) so the page stays a snapshot.
@Observable @MainActor
final class NotificationsSpecimenState {
    enum Kind { case success, info, warning, error }
    enum Column { case closed, details, history }

    struct Event: Identifiable, Equatable {
        let id = UUID()
        let kind: Kind
        let icon: String
        let message: String
        let server: String
        var link: String?
        var date = Date()
        var count = 1

        func copy() -> Event { Event(kind: kind, icon: icon, message: message, server: server, link: link) }

        var tint: Color {
            switch kind {
            case .success: ColorTokens.Status.success
            case .info: ColorTokens.Text.secondary
            case .warning: ColorTokens.Status.warning
            case .error: ColorTokens.Status.error
            }
        }
    }

    /// Echo's values: three toasts at most; 3 s before a toast goes; errors stay.
    static let maximumVisible = 3
    static let toastDuration: Double = 3

    var toasts: [Event] = []
    var hoveredID: UUID?
    var history: [Event] = []
    var unread = 0
    /// What was new when the history last opened: bold, and counted beside the title.
    var newIDs: Set<UUID> = []
    var column: Column = .closed

    private var nextSample = 0

    static let samples: [Event] = [
        Event(kind: .success, icon: "checkmark.circle.fill", message: "Connected to Test MSSQL", server: "Test MSSQL", link: "Show Server"),
        Event(kind: .error, icon: "exclamationmark.octagon.fill", message: "Query 1 failed: Query Error: relation \"public.employees\" does not exist. LINE 2: from public.employees. HINT: Perhaps you meant to reference the table \"employees.employee\".", server: "postgres18", link: "Open Tab"),
        Event(kind: .error, icon: "exclamationmark.triangle", message: "Backup failed for sales: Operating system error 5 (Access is denied.) while writing to /var/opt/mssql/backup/sales.bak", server: "Test MSSQL", link: "Show Server"),
        Event(kind: .info, icon: "arrow.triangle.swap", message: "Switched to sales", server: "tippr", link: "Open Tab"),
    ]

    init() {
        history = Self.samples.reversed().map { event in
            var old = event
            old.date = Date().addingTimeInterval(-Double.random(in: 300...20_000))
            return old
        }
    }

    func post() {
        let sample = Self.samples[nextSample % Self.samples.count]
        nextSample += 1
        show(Event(kind: sample.kind, icon: sample.icon, message: sample.message, server: sample.server, link: sample.link))
    }

    func repeatLatest() {
        guard let latest = toasts.first else { return post() }
        show(Event(kind: latest.kind, icon: latest.icon, message: latest.message, server: latest.server, link: latest.link))
    }

    /// A repeat counts up and moves to the top; the stack keeps three.
    private func show(_ event: Event) {
        history.insert(event, at: 0)
        unread += 1
        var toast = event
        if let index = toasts.firstIndex(where: { $0.message == event.message && $0.kind == event.kind }) {
            toast = toasts.remove(at: index)
            toast.count += 1
        }
        toasts.insert(toast, at: 0)
        if toasts.count > Self.maximumVisible { toasts.removeLast() }
        guard toast.kind != .error else { return }
        let id = toast.id
        let count = toast.count
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.toastDuration))
            while self?.hoveredID == id { try? await Task.sleep(for: .milliseconds(300)) }
            guard let self, self.toasts.first(where: { $0.id == id })?.count == count else { return }
            self.dismiss(id)
        }
    }

    func dismiss(_ id: UUID) {
        toasts.removeAll { $0.id == id }
        if hoveredID == id { hoveredID = nil }
    }

    /// The Spec page forces the specimen into a state: "toast" (an error toast showing), "toastOpen"
    /// (the same, hovered open) or "history" (the history in the column); nil leaves it alone.
    func force(_ key: String?) {
        switch key {
        case "toast", "toastOpen":
            if toasts.isEmpty { show(Self.samples[1].copy()) }
            hoveredID = key == "toastOpen" ? toasts.first?.id : nil
        case "history":
            if column != .history { toggleHistory() }
        default:
            break
        }
    }

    /// The bell: shows the history in the column, or puts it away.
    func toggleHistory() {
        if column == .history {
            column = .closed
        } else {
            column = .history
            newIDs = Set(history.prefix(unread).map(\.id))
            unread = 0
        }
    }

    /// The inspector button: from the history it switches to the details.
    func toggleInspector() {
        column = column == .details ? .closed : .details
    }
}
