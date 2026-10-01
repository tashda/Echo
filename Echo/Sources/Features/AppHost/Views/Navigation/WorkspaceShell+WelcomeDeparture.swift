import SwiftUI

/// The first connection from the welcome (round 48): the welcome's pills echo out first (LV2),
/// then the server grows into the rail, then the tree slides out 0.12 s later (CO1). The rail and
/// the tree stay empty until their turn; the welcome and the server page read the same state
/// (`AppState.welcomeDeparture`).
extension WorkspaceShell {
    /// A server is in the rail, or connecting.
    var hasConnectionActivity: Bool {
        !environmentState.sessionGroup.sessions.isEmpty || !environmentState.pendingConnections.isEmpty
    }

    /// Whether the welcome is what the canvas shows.
    private var isWelcomeShowing: Bool {
        tabStore.tabs.isEmpty && environmentState.sessionGroup.activeSession == nil
    }

    func updateWelcomeDeparture(isActive: Bool) {
        departureTask?.cancel()
        departureTask = nil

        guard isActive, isWelcomeShowing, !motion.reduceMotion else {
            appState.welcomeDeparture = .idle
            return
        }

        let scale = motion.durationScale
        appState.welcomeDeparture = .leaving
        departureTask = Task(name: "welcome-departure") {
            try? await Task.sleep(for: .seconds(WelcomeMarkMotion.railDelay * scale))
            guard !Task.isCancelled else { return }
            appState.welcomeDeparture = .railIn
            try? await Task.sleep(for: .seconds(WelcomeMarkMotion.treeLag * scale))
            guard !Task.isCancelled else { return }
            appState.welcomeDeparture = .idle
        }
    }
}
