import SwiftUI
import HatchCore
import HatchAgent

/// Starts Iris (HatchAgent's `VettingService`) for a ticket in Checking, off the main thread.
/// What she leaves behind: questions (`store.ask(... by: "Iris")`), a `vetting` event holding a `VettingSuggestion`
/// (rewrite, type change, duplicate), and either Needs answers or Ready. A failed run leaves the ticket in Checking with a
/// `vetting-failed` event; `IrisReviewView` shows the reason and offers "Check again".
@MainActor
enum VettingBridge {
    private static var running = Set<Int>()

    static var isAvailable: Bool { true }

    static func start(ticketId: Int, state: AppState) {
        guard !running.contains(ticketId) else { return }
        let store = state.store
        guard let claude = HXAskAdapter.locateClaude(setting: state.hxSetting("claude_path")) else {
            try? store.record(ticketId, actor: "Iris", kind: "vetting-failed",
                              payload: ["reason": .string("Could not find the claude program. Set its path in Settings.")])
            state.refresh()
            return
        }
        running.insert(ticketId)
        Task { @MainActor in
            await Task.detached {
                let runner = ClaudeCLIRunner(executable: claude, workingDirectory: URL(fileURLWithPath: NSHomeDirectory()), timeout: 240)
                let service = VettingService(store: store, runner: runner)
                do {
                    _ = try service.vet(ticketId: ticketId)
                } catch {
                    try? store.record(ticketId, actor: "Iris", kind: "vetting-failed", payload: ["reason": .string("\(error)")])
                }
            }.value
            running.remove(ticketId)
            state.refresh()
        }
    }
}
