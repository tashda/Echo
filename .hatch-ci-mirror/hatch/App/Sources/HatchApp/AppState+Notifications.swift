import SwiftUI
import Combine
import UserNotifications
import HatchCore

/// Posts a macOS notification when a ticket becomes Your call or To verify (decision B6).
/// It watches `AppState.$revision` with a Combine sink. Start it once with `NotificationCenterBridge.shared.start(state:)`
/// or by adding `.hatchNotifications(state)` to any always-present view (it starts lazily on first appearance).
@MainActor
final class NotificationCenterBridge: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterBridge()

    private var cancellable: AnyCancellable?
    private weak var state: AppState?
    private var known: [Int: Status] = [:]
    private var primed = false

    /// Notifications need a real app bundle; a bare `swift run` binary has none and would crash.
    private var canNotify: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    func start(state: AppState) {
        if cancellable != nil { return }
        self.state = state
        if canNotify {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        scan()
        cancellable = state.$revision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.scan() }
            }
    }

    // MARK: Watching

    private func scan() {
        guard let state else { return }
        let filter = TicketFilter(statuses: [.yourCall, .toVerify])
        let waiting = (try? state.store.tickets(filter)) ?? []
        var next: [Int: Status] = [:]
        for t in waiting { next[t.id] = t.status }
        if primed {
            for t in waiting where known[t.id] != t.status { post(t) }
        }
        known = next
        primed = true
    }

    private func post(_ t: Ticket) {
        guard canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = t.status == .yourCall ? "Your call: \(t.displayNumber)" : "To verify: \(t.displayNumber)"
        content.body = t.title
        content.sound = .default
        content.userInfo = ["ticketId": t.id]
        let request = UNNotificationRequest(identifier: "hatch-\(t.id)-\(t.status.rawValue)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: Clicking a notification opens the ticket

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.content.userInfo["ticketId"] as? Int
        Task { @MainActor in
            if let id, let state = NotificationCenterBridge.shared.state, let ticket = try? state.store.ticket(id: id) {
                NSApp.activate(ignoringOtherApps: true)
                state.open(ticket)
            }
        }
        completionHandler()
    }
}

extension AppState {
    /// Starts the notification bridge for this state (safe to call many times).
    func startNotifications() {
        NotificationCenterBridge.shared.start(state: self)
    }
}

private struct HXNotificationHook: ViewModifier {
    let state: AppState

    func body(content: Content) -> some View {
        content.onAppear { state.startNotifications() }
    }
}

extension View {
    /// Add to an always-present view (for example the window content) to start Dock-style notifications.
    func hatchNotifications(_ state: AppState) -> some View {
        modifier(HXNotificationHook(state: state))
    }
}
