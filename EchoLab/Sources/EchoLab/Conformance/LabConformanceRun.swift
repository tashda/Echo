import AppKit
import EchoDesignSystem
import SwiftUI

/// The reference side of a conformance check. Launched with `ECHO_CONFORMANCE=<request>` (by
/// `EchoLab/Scripts/verify-round.py --reference`), Echo Labs draws the round's accepted exhibit
/// with the owner's picks, captures every conformance state, writes `contract.json` and quits.
@MainActor
enum LabConformanceRun {
    struct Contract: Encodable {
        struct State: Encodable {
            let id: String
            let title: String
            let settle: Double
            let observe: Double
        }

        let page: String
        let title: String
        let exhibit: String
        let exhibitTitle: String
        /// Every control's value as drawn: the owner's pick, or the default for playground knobs.
        let values: [String: String]
        let picks: [String: String]
        /// Controls with a question the owner left unpicked (drawn at their default).
        let unpicked: [String]
        let width: Double
        let height: Double
        let subject: String
        let states: [State]
        let knownDifferences: [String: String]
        let shots: [ConformanceShot]
    }

    enum Failure: Error, CustomStringConvertible {
        case noRound(String)
        case noConformance(String)

        var description: String {
            switch self {
            case .noRound(let id): "No round page with id \(id)"
            case .noConformance(let id): "Round \(id) has no `conformance` in its RoundSpec"
            }
        }
    }

    /// Starts the capture when the process was launched for one. Returns whether it did.
    static func startIfRequested() -> Bool {
        guard let request = ConformanceRequest.load() else { return false }
        Task(name: "conformance-reference") {
            // Let the app finish launching before opening windows.
            try? await Task.sleep(for: .seconds(1))
            do {
                try await capture(request)
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Conformance capture failed: \(error)\n".utf8))
                exit(1)
            }
        }
        return true
    }

    private static func capture(_ request: ConformanceRequest) async throws {
        guard let page = LabRegistry.page(id: request.page), let spec = page.roundSpec else { throw Failure.noRound(request.page) }
        guard let conformance = spec.conformance else { throw Failure.noConformance(request.page) }
        let picks = request.picks ?? [:]
        let exhibit = spec.exhibits.first { $0.id == picks[RoundSpec.exhibitTopicID] }
            ?? spec.exhibits.first { !$0.isEchoToday } ?? spec.exhibits[0]

        var values: [String: String] = [:]
        var unpicked: [String] = []
        for control in spec.controls {
            if let pick = picks[control.id], control.choices.contains(where: { $0.id == pick }) {
                values[control.id] = pick
            } else {
                values[control.id] = control.defaultChoice
                if control.question != nil { unpicked.append(control.id) }
            }
        }
        let fixed = RoundValues(fixed: values)
        let states = conformance.states.map { ConformanceRequest.State(id: $0.id, settle: $0.settle, observe: $0.observe) }
        let shots = try await ConformanceCapture.run(
            request: request, states: states,
            size: CGSize(width: exhibit.designWidth, height: exhibit.designHeight)
        ) { state in
            AnyView(exhibit.build(fixed).environment(\.labConformanceState, state))
        }

        let contract = Contract(
            page: page.id, title: page.title, exhibit: exhibit.id, exhibitTitle: exhibit.title,
            values: values, picks: picks, unpicked: unpicked,
            width: exhibit.designWidth, height: exhibit.designHeight, subject: conformance.subject,
            states: conformance.states.map { .init(id: $0.id, title: $0.title, settle: $0.settle, observe: $0.observe) },
            knownDifferences: conformance.knownDifferences, shots: shots)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(contract).write(to: URL(fileURLWithPath: request.out).appendingPathComponent("contract.json"))
    }
}
