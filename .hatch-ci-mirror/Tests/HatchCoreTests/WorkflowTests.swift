import XCTest
@testable import HatchCore

final class WorkflowTests: XCTestCase {
    func testEveryTypeFollowsItsPathWithLegalMoves() {
        for type in TicketType.allCases {
            let path = Workflow.path(for: type)
            XCTAssertEqual(path.first, .draft)
            XCTAssertEqual(path.last, .done)
            // Every consecutive pair on the path must be reachable by someone, directly or through another path status.
            var reachable: Set<Status> = [.draft]
            var frontier: [Status] = [.draft]
            while let s = frontier.popLast() {
                for actor in [Actor.owner, .agent, .hatch] {
                    for n in Workflow.nextStatuses(type: type, from: s, actor: actor) where !reachable.contains(n) {
                        reachable.insert(n); frontier.append(n)
                    }
                }
            }
            for status in path { XCTAssertTrue(reachable.contains(status), "\(type) cannot reach \(status)") }
        }
    }

    func testTurnsMatchTheDesign() {
        XCTAssertEqual(Status.yourCall.turn, .you)
        XCTAssertEqual(Status.needsAnswers.turn, .you)
        XCTAssertEqual(Status.toVerify.turn, .you)
        XCTAssertEqual(Status.checking.turn, .agent)
        XCTAssertEqual(Status.building.turn, .agent)
        XCTAssertEqual(Status.accepted.turn, .hatch)
        XCTAssertEqual(Status.done.turn, .finished)
        XCTAssertEqual(Status.parked.turn, .paused)
        XCTAssertEqual(Status.allCases.count, 16)
    }

    func testOnlyOwnerAcceptsAndOnlyForProposals() {
        XCTAssertTrue(Workflow.isAllowed(type: .proposal, from: .yourCall, to: .accepted, actor: .owner))
        XCTAssertFalse(Workflow.isAllowed(type: .proposal, from: .yourCall, to: .accepted, actor: .agent))
        XCTAssertFalse(Workflow.isAllowed(type: .tweak, from: .yourCall, to: .accepted, actor: .owner))
    }

    func testAgentCannotMarkItsOwnWorkVerifiedOrMerged() {
        XCTAssertFalse(Workflow.isAllowed(type: .tweak, from: .building, to: .toVerify, actor: .agent))
        XCTAssertTrue(Workflow.isAllowed(type: .tweak, from: .building, to: .toVerify, actor: .hatch))
        XCTAssertFalse(Workflow.isAllowed(type: .tweak, from: .toVerify, to: .merged, actor: .agent))
        XCTAssertFalse(Workflow.isAllowed(type: .tweak, from: .toVerify, to: .merged, actor: .owner))
        XCTAssertTrue(Workflow.isAllowed(type: .tweak, from: .toVerify, to: .merged, actor: .hatch))
    }

    func testTweaksAndBugsSkipExploring() {
        XCTAssertTrue(Workflow.isAllowed(type: .tweak, from: .ready, to: .building, actor: .agent))
        XCTAssertFalse(Workflow.isAllowed(type: .tweak, from: .ready, to: .preparing, actor: .agent))
        XCTAssertTrue(Workflow.isAllowed(type: .proposal, from: .ready, to: .preparing, actor: .agent))
        XCTAssertFalse(Workflow.isAllowed(type: .proposal, from: .ready, to: .building, actor: .agent))
    }

    func testOwnerCanParkAndDropFromAnyOpenStatusButNotFromDone() {
        for s in Status.allCases where s != .done && s != .dropped && s != .parked {
            XCTAssertTrue(Workflow.isAllowed(type: .bug, from: s, to: .parked, actor: .owner), "\(s)")
        }
        XCTAssertFalse(Workflow.isAllowed(type: .bug, from: .done, to: .parked, actor: .owner))
    }

    func testStatusLabelsAreStableBecauseGitHubDependsOnThem() {
        XCTAssertEqual(Status.yourCall.label, "status:your-call")
        XCTAssertEqual(Status.needsAnswers.label, "status:needs-answers")
        XCTAssertEqual(Status.toVerify.label, "status:to-verify")
        XCTAssertEqual(TicketType.proposal.label, "type:proposal")
    }
}

final class GlobTests: XCTestCase {
    func testMatching() {
        XCTAssertTrue(Glob.matches("Echo/Sources/Features/Notifications/**", "Echo/Sources/Features/Notifications/Toast/ToastView.swift"))
        XCTAssertFalse(Glob.matches("Echo/Sources/Features/Notifications/**", "Echo/Sources/Features/Explorer/RowView.swift"))
        XCTAssertTrue(Glob.matches("**/*.swift", "a/b/c.swift"))
        XCTAssertTrue(Glob.matches("a/?.swift", "a/b.swift"))
        XCTAssertFalse(Glob.matches("a/*.swift", "a/b/c.swift"))
    }

    func testOverlapIsConservative() {
        XCTAssertTrue(Glob.mayOverlap("Echo/Explorer/**", "Echo/Explorer/RowView.swift"))
        XCTAssertTrue(Glob.mayOverlap("Echo/Explorer/RowView.swift", "Echo/Explorer/RowView.swift"))
        XCTAssertFalse(Glob.mayOverlap("Echo/Explorer/RowView.swift", "Echo/Explorer/RowMetrics.swift"))
        XCTAssertFalse(Glob.mayOverlap("Echo/Explorer/**", "Echo/Notifications/**"))
    }
}
