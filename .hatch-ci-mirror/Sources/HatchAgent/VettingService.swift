import Foundation
import HatchCore

public enum VettingOutcome: Equatable, Sendable {
    /// Iris answered and her result was applied.
    case vetted(IrisOutcome)
    /// The run failed or the answer was unusable. The ticket stays in Checking and an event says why.
    case failed(String)
}

/// Runs the whole check for one ticket: request, prompt, model, parse, apply, and token accounting (decision K5).
public struct VettingService {
    public let store: HatchStore
    public let runner: AgentRunner
    public var options: AgentOptions

    public init(store: HatchStore, runner: AgentRunner, options: AgentOptions = AgentOptions()) {
        self.store = store; self.runner = runner; self.options = options
    }

    @discardableResult
    public func vet(ticketId: Int) throws -> VettingOutcome {
        guard let t = try store.ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
        guard t.status == .checking else {
            throw StoreError.invalid("\(t.displayNumber) is \(t.status.displayName); only a Checking ticket is vetted.")
        }
        let request = try VettingRequest.build(store: store, ticketId: ticketId)
        let runId = try store.startRun(ticketId: ticketId, agent: IrisApplier.name, step: "vet")

        let output: AgentOutput
        do { output = try runner.run(prompt: IrisPrompt.make(request), options: options) }
        catch {
            return try fail(ticketId, runId, tokensIn: 0, tokensOut: 0, outcome: "failed", reason: "\(error)")
        }
        do {
            let result = try IrisResult.parse(output.text)
            let applied = try IrisApplier.apply(result, to: ticketId, store: store)
            try store.endRun(runId, tokensIn: output.tokensIn, tokensOut: output.tokensOut, outcome: "ok")
            return .vetted(applied)
        } catch {
            // The tokens were spent even though the answer was unusable, so they are still counted.
            return try fail(ticketId, runId, tokensIn: output.tokensIn, tokensOut: output.tokensOut, outcome: "unusable", reason: "\(error)")
        }
    }

    private func fail(_ ticketId: Int, _ runId: Int, tokensIn: Int, tokensOut: Int, outcome: String, reason: String) throws -> VettingOutcome {
        try store.endRun(runId, tokensIn: tokensIn, tokensOut: tokensOut, outcome: outcome)
        try store.record(ticketId, actor: IrisApplier.name, kind: "vetting-failed", payload: ["reason": .string(reason)])
        return .failed(reason)
    }
}
