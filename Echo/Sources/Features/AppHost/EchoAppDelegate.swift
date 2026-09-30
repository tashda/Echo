#if os(macOS)
import AppKit

/// Quitting with PostgreSQL transactions still open asks once, listing the tabs (Echo Labs round 21,
/// open transaction on close, Q1): Review, Roll Back All, Cancel.
@MainActor
final class EchoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let environment = AppDirector.shared.environmentState
        let tabs = environment.tabStore.tabs.filter { environment.mayHaveOpenTransaction($0) }
        guard !tabs.isEmpty else { return .terminateNow }
        Task { @MainActor in
            let mayQuit = await environment.confirmOpenTransactions(in: tabs, for: .quit)
            sender.reply(toApplicationShouldTerminate: mayQuit)
        }
        return .terminateLater
    }
}
#endif
