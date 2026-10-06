import AppKit
import Testing
@testable import Echo

@MainActor
@Suite("Window drag pause")
struct WindowDragPauseTests {
    private func makeWindow() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: true)
    }

    @Test func holdsTheWindowStillThenLetsItMove() async throws {
        let window = makeWindow()
        WindowDragPause.pause(window, for: 0.05)
        #expect(!window.isMovable)
        try await Task.sleep(for: .milliseconds(300))
        #expect(window.isMovable)
    }

    @Test func aSecondPauseExtendsTheFirst() async throws {
        let window = makeWindow()
        WindowDragPause.pause(window, for: 0.05)
        WindowDragPause.pause(window, for: 0.5)
        try await Task.sleep(for: .milliseconds(200))
        #expect(!window.isMovable)
        try await Task.sleep(for: .milliseconds(600))
        #expect(window.isMovable)
    }

    @Test func leavesAnUnmovableWindowAlone() async throws {
        let window = makeWindow()
        window.isMovable = false
        WindowDragPause.pause(window, for: 0.05)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!window.isMovable)
    }

    @Test func aLiveResizeHoldsTheWindowStillUntilItEnds() {
        let window = makeWindow()
        WindowDragPause.holdStill(window)
        #expect(!window.isMovable)
        WindowDragPause.release(window)
        #expect(window.isMovable)
    }

    @Test func releasingAWindowThatWasNotHeldChangesNothing() {
        let window = makeWindow()
        window.isMovable = false
        WindowDragPause.holdStill(window)
        WindowDragPause.release(window)
        #expect(!window.isMovable)
    }

    @Test func aPauseInProgressIsLeftToItsOwnTimer() async throws {
        let window = makeWindow()
        WindowDragPause.pause(window, for: 0.1)
        WindowDragPause.holdStill(window)
        WindowDragPause.release(window)
        #expect(!window.isMovable)
        try await Task.sleep(for: .milliseconds(400))
        #expect(window.isMovable)
    }
}
