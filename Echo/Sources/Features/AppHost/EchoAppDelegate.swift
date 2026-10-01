#if os(macOS)
import AppKit

/// Quitting with PostgreSQL transactions still open asks once, listing the tabs (Echo Labs round 21,
/// open transaction on close, Q1): Review, Roll Back All, Cancel.
@MainActor
final class EchoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Every horizontal scroll bar gets the same blur behind it (round 27, U5).
        ScrollBarBlurHook.install()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let environment = AppDirector.shared.environmentState
        let allTabs = environment.tabStore.tabs
        let tabs = allTabs.filter { environment.mayHaveOpenTransaction($0) }
        // Echo doesn't restore tabs, so unsaved queries ask first (owner, 2026-10-01).
        let hasUnsaved = allTabs.contains { environment.hasUnsavedChanges($0) }
        guard !tabs.isEmpty || hasUnsaved else { return .terminateNow }
        Task { @MainActor in
            var mayQuit = await environment.confirmUnsavedChangesBeforeLosing(allTabs)
            if mayQuit, !tabs.isEmpty {
                mayQuit = await environment.confirmOpenTransactions(in: tabs, for: .quit)
            }
            sender.reply(toApplicationShouldTerminate: mayQuit)
        }
        return .terminateLater
    }
}
#endif
