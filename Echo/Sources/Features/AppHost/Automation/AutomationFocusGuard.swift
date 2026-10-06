#if DEBUG
import AppKit

/// Keeps an automated run out of the way of the person at the Mac: a click, a menu or a text field in Echo's window makes
/// the app active, which brings it in front of whatever they were working in. While steps run (and shortly after one),
/// Echo hands the focus back the moment it takes it. The window stays visible, so it keeps drawing as it would.
/// On with automation unless `ECHO_AUTOMATION_KEEP_FOCUS=0`.
@MainActor
enum AutomationFocusGuard {
    private static var lastStep = Date.distantPast
    private static var observer: NSObjectProtocol?

    static func stepStarted() { lastStep = Date() }

    static func startIfRequested() {
        guard observer == nil, ProcessInfo.processInfo.environment["ECHO_AUTOMATION_KEEP_FOCUS"] != "0" else { return }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                // Only what a step caused: someone switching to Echo on purpose is left alone.
                guard Date().timeIntervalSince(lastStep) < 2.5 else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(30))
                    NSApp.deactivate()
                }
            }
        }
    }
}
#endif
