import Foundation
import Testing
@testable import Echo

/// The welcome mark's clock stops when the mark does: a clock that is always asked for one more entry keeps the whole
/// window redrawing at the display's rate.
@Suite("Welcome mark clock")
struct WelcomeMarkClockTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func aMarkAtRestOrNotYetShownNeedsNoClock() {
        for phase in [WelcomeMarkPhase.hidden, .resting] {
            let clock = WelcomeMarkClock(phase: phase, scale: 1)
            #expect(!clock.isMoving(at: start))
            #expect(clock.entries(from: start, mode: .normal).isEmpty)
        }
    }

    @Test func aPlayingMarkTicksEveryFrameUntilItEnds() throws {
        let clock = WelcomeMarkClock(phase: .playing(start), scale: 1)
        let entries = clock.entries(from: start, mode: .normal)
        #expect(clock.isMoving(at: start.addingTimeInterval(0.5)))
        #expect(entries.count > 60)
        let last = try #require(entries.last)
        #expect(last.timeIntervalSince(start) >= 1.2)
        #expect(entries.first == start)
    }

    @Test func afterTheMotionThereAreNoMoreEntries() {
        let clock = WelcomeMarkClock(phase: .playing(start), scale: 1)
        let after = start.addingTimeInterval(5)
        #expect(!clock.isMoving(at: after))
        #expect(clock.entries(from: after, mode: .normal).isEmpty)
    }

    @Test func aLeavingMarkTicksOnlyForItsShortMotion() {
        let clock = WelcomeMarkClock(phase: .leaving(start), scale: 1)
        #expect(clock.isMoving(at: start.addingTimeInterval(0.2)))
        #expect(!clock.isMoving(at: start.addingTimeInterval(1)))
    }

    @Test func theSpeedSettingStretchesTheMotion() {
        let slow = WelcomeMarkClock(phase: .playing(start), scale: 2)
        #expect(slow.isMoving(at: start.addingTimeInterval(2)))
    }
}
