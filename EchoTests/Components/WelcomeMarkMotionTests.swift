import Foundation
import Testing
@testable import Echo

/// The welcome's mark follows echodb.dev's Mark.astro curve; these pin the curve and the pills'
/// start and end places (round 48).
@Suite("Welcome mark motion")
struct WelcomeMarkMotionTests {
    @Test func bezierStartsAtZeroAndEndsAtOne() {
        #expect(WelcomeMarkMotion.bezier(0, 0.3, 1.3, 0.5, 1) == 0)
        #expect(WelcomeMarkMotion.bezier(1, 0.3, 1.3, 0.5, 1) == 1)
    }

    @Test func websiteCurveOvershootsBeforeSettling() {
        let peak = stride(from: 0.05, to: 1.0, by: 0.05).map { WelcomeMarkMotion.bezier($0, 0.3, 1.3, 0.5, 1) }.max() ?? 0
        #expect(peak > 1.02)
    }

    @Test func linearBezierIsTheIdentity() {
        for x in stride(from: 0.1, to: 1.0, by: 0.2) {
            #expect(abs(WelcomeMarkMotion.bezier(x, 1.0 / 3, 1.0 / 3, 2.0 / 3, 2.0 / 3) - x) < 0.001)
        }
    }

    @Test func pillsStartHiddenToTheLeftAndRestInPlace() {
        let hidden = WelcomeMarkMotion.pillFrame(phase: .hidden, index: 0, at: Date(), scale: 1)
        #expect(hidden.offset == -WelcomeMarkMotion.travel)
        #expect(hidden.opacity == 0)

        let start = Date()
        let end = start.addingTimeInterval(WelcomeMarkMotion.pillDuration + WelcomeMarkMotion.pillStagger * 2 + 0.01)
        for index in 0..<3 {
            let frame = WelcomeMarkMotion.pillFrame(phase: .playing(start), index: index, at: end, scale: 1)
            #expect(frame.offset == 0)
            #expect(frame.opacity == 1)
        }
    }

    @Test func pillsEchoInOneAfterAnother() {
        let start = Date()
        let moment = start.addingTimeInterval(0.3)
        let offsets = (0..<3).map { WelcomeMarkMotion.pillFrame(phase: .playing(start), index: $0, at: moment, scale: 1).offset }
        #expect(offsets[0] > offsets[1])
        #expect(offsets[1] > offsets[2])
    }

    @Test func slowMotionStretchesTheEcho() {
        let start = Date()
        let normal = WelcomeMarkMotion.pillFrame(phase: .playing(start), index: 0, at: start.addingTimeInterval(0.3), scale: 1)
        let slow = WelcomeMarkMotion.pillFrame(phase: .playing(start), index: 0, at: start.addingTimeInterval(0.3), scale: 3)
        #expect(slow.offset < normal.offset)
    }

    @Test func leavingPillsGoLeftAndFadeLastPillFirst() {
        let start = Date()
        let moment = start.addingTimeInterval(0.2)
        let frames = (0..<3).map { WelcomeMarkMotion.pillFrame(phase: .leaving(start), index: $0, at: moment, scale: 1) }
        #expect(frames[2].offset < frames[1].offset)
        #expect(frames[1].offset < frames[0].offset)

        let done = WelcomeMarkMotion.pillFrame(phase: .leaving(start), index: 0, at: start.addingTimeInterval(WelcomeMarkMotion.leaveTotal + 0.01), scale: 1)
        #expect(done.opacity == 0)
        #expect(done.offset == -WelcomeMarkMotion.travel)
    }

    @Test func theRailWaitsForThePillsToLeave() {
        #expect(WelcomeMarkMotion.railDelay > WelcomeMarkMotion.leaveTotal)
    }
}
