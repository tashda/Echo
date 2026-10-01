#if os(macOS)
import AppKit

/// Holds the workspace window still while an animation runs.
///
/// Whenever hit-testable SwiftUI content moves or fades, AppKit recomputes the window's drag
/// regions at the end of the frame: it asks the root hosting view whether it accepts first
/// responder, and SwiftUI answers by walking the focus order of the whole window. During an
/// Explorer section switch that was a third of the main thread, every frame (traced 2026-10-01).
/// A window that isn't movable skips the work, so an animation pauses movability for its length.
/// The only cost: a window drag started in those few hundred milliseconds doesn't start.
@MainActor
enum WindowDragPause {
    private static var resumeTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// Pauses the workspace window's movability for `seconds`, extending a pause already running.
    static func pauseWorkspace(for seconds: Double) {
        guard let window = NSApp.windows.first(where: { $0.identifier == AppWindowIdentifier.workspace }) else { return }
        pause(window, for: seconds)
    }

    static func pause(_ window: NSWindow, for seconds: Double) {
        guard !window.styleMask.contains(.fullScreen) else { return }
        let id = ObjectIdentifier(window)
        if resumeTasks[id] == nil {
            // A window that was never movable stays as it is.
            guard window.isMovable else { return }
            window.isMovable = false
        }
        resumeTasks[id]?.cancel()
        resumeTasks[id] = Task(name: "window-drag-pause") { [weak window] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            window?.isMovable = true
            resumeTasks[id] = nil
        }
    }
}
#endif
