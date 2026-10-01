import Foundation
import Testing
@testable import Echo

/// Round 33.2: what a step does when it finishes (OC1), and Edit Step's last-run line (ES1).
@MainActor
struct AgentJobStepSheetTests {
    @Test func aNewStepGoesOnOrQuitsWithFailureAndDoesNotRetry() {
        let outcome = AgentJobStepOutcome()
        #expect(outcome.onSuccess == .nextStep)
        #expect(outcome.onFailure == .quitWithFailure)
        #expect(outcome.retryAttempts == 0)
    }

    @Test func agentActionsMapBothWays() {
        let outcome = AgentJobStepOutcome(onSuccessAction: 4, onSuccessStepID: 3, onFailureAction: 1, onFailureStepID: nil,
                                          retryAttempts: 2, retryIntervalMinutes: 5)
        #expect(outcome.onSuccess == .step(3))
        #expect(outcome.onSuccess.action == 4 && outcome.onSuccess.stepID == 3)
        #expect(outcome.onFailure == .quitWithSuccess)
        #expect(outcome.onFailure.action == 1 && outcome.onFailure.stepID == nil)
        #expect(outcome.retryAttempts == 2 && outcome.retryIntervalMinutes == 5)
        #expect(AgentJobStepOutcome.Target.nextStep.action == 3)
        #expect(AgentJobStepOutcome.Target.quitWithFailure.action == 2)
    }

    @Test func unknownActionsFallBackToTheServersDefaults() {
        let outcome = AgentJobStepOutcome(onSuccessAction: nil, onSuccessStepID: nil, onFailureAction: 4, onFailureStepID: nil,
                                          retryAttempts: nil, retryIntervalMinutes: nil)
        #expect(outcome.onSuccess == .quitWithSuccess)
        #expect(outcome.onFailure == .quitWithFailure)
        #expect(outcome.retryAttempts == 0)
    }

    @Test func targetsListTheOtherStepsInOrder() {
        let targets = AgentJobStepOutcome.targets(otherSteps: [3, 1])
        #expect(targets == [.nextStep, .quitWithSuccess, .quitWithFailure, .step(1), .step(3)])
        #expect(AgentJobStepOutcome.Target.step(3).title(stepNames: [3: "Rebuild"]) == "Go to step 3: Rebuild")
    }

    @Test func theLastRunLineUsesTheStepsLatestRun() {
        let history = [
            JobQueueViewModel.HistoryRow(id: 1, jobName: "Nightly", stepId: 1, stepName: "Check", status: 0, message: "",
                                         runDate: 20_260_919, runTime: 230_000, runDuration: 1_351),
            JobQueueViewModel.HistoryRow(id: 2, jobName: "Nightly", stepId: 1, stepName: "Check", status: 1, message: "",
                                         runDate: 20_260_926, runTime: 230_000, runDuration: 1_400),
            JobQueueViewModel.HistoryRow(id: 3, jobName: "Nightly", stepId: 0, stepName: "(Job outcome)", status: 1, message: "",
                                         runDate: 20_260_927, runTime: 10_000, runDuration: 5),
        ]
        let line = AgentJobStepLastRun.line(stepID: 1, history: history, locale: Locale(identifier: "en_GB"),
                                            timeZone: TimeZone(identifier: "UTC") ?? .gmt)
        // The latest run of step 1 (26 Sep, not 19 Sep), its outcome and duration; the date's spelling is the locale's.
        let text = line
        #expect(text?.hasPrefix("Last run 26") == true)
        #expect(text?.contains("23:00") == true)
        #expect(text?.hasSuffix(" · Succeeded · 14 min") == true)
        #expect(AgentJobStepLastRun.line(stepID: 2, history: history) == nil)
    }

    @Test func durationsReadLikeTheHistory() {
        #expect(AgentJobStepLastRun.duration(42) == "42 s")
        #expect(AgentJobStepLastRun.duration(1_400) == "14 min")
        #expect(AgentJobStepLastRun.duration(11_200) == "1 h 12 min")
        #expect(AgentJobStepLastRun.duration(20_000) == "2 h")
    }
}
