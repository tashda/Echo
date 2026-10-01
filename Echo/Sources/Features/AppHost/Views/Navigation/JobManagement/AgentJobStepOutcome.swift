import Foundation

/// What a job step does when it finishes (round 33.2, OC1): where it goes on success and on
/// failure, and how often it retries first. SQL Agent's actions: 1 quit reporting success,
/// 2 quit reporting failure, 3 go to the next step, 4 go to a given step.
nonisolated struct AgentJobStepOutcome: Hashable, Sendable {
    enum Target: Hashable, Sendable {
        case nextStep
        case quitWithSuccess
        case quitWithFailure
        case step(Int)

        var action: Int {
            switch self {
            case .quitWithSuccess: 1
            case .quitWithFailure: 2
            case .nextStep: 3
            case .step: 4
            }
        }

        var stepID: Int? {
            if case .step(let id) = self { return id }
            return nil
        }

        init(action: Int?, stepID: Int?, fallback: Target) {
            switch action {
            case 1: self = .quitWithSuccess
            case 2: self = .quitWithFailure
            case 3: self = .nextStep
            case 4: self = stepID.map(Target.step) ?? fallback
            default: self = fallback
            }
        }

        func title(stepNames: [Int: String]) -> String {
            switch self {
            case .nextStep: "Go to the next step"
            case .quitWithSuccess: "Quit the job reporting success"
            case .quitWithFailure: "Quit the job reporting failure"
            case .step(let id): stepNames[id].map { "Go to step \(id): \($0)" } ?? "Go to step \(id)"
            }
        }
    }

    /// SSMS's defaults for a new step.
    var onSuccess: Target = .nextStep
    var onFailure: Target = .quitWithFailure
    var retryAttempts = 0
    var retryIntervalMinutes = 1

    static let maximumRetryAttempts = 99
    static let maximumRetryIntervalMinutes = 1_440
}

extension AgentJobStepOutcome {
    init(onSuccessAction: Int?, onSuccessStepID: Int?, onFailureAction: Int?, onFailureStepID: Int?,
         retryAttempts: Int?, retryIntervalMinutes: Int?) {
        self.init(
            onSuccess: Target(action: onSuccessAction, stepID: onSuccessStepID, fallback: .quitWithSuccess),
            onFailure: Target(action: onFailureAction, stepID: onFailureStepID, fallback: .quitWithFailure),
            retryAttempts: retryAttempts ?? 0,
            retryIntervalMinutes: retryIntervalMinutes ?? 0
        )
    }

    /// The targets a step can choose: the fixed ones, then every other step of the job.
    static func targets(otherSteps: [Int]) -> [Target] {
        [.nextStep, .quitWithSuccess, .quitWithFailure] + otherSteps.sorted().map(Target.step)
    }
}
