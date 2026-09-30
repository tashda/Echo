import SwiftUI

/// Round 15 · where Run lives, as a `RoundSpec`: five places, one simulated query.
@MainActor
enum RunRound {
    static let simulation = LabRunSimulation()

    static let spec = RoundSpec(
        controls: [
            .of("outcome", "The query", LabRunOutcome.self, default: .success),
            .of("length", "Takes", LabRunLength.self, default: .quick),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        actions: [
            .init(id: "run", title: "Run or cancel", symbol: "play.fill") { _ in simulation.toggle() },
            .init(id: "finish", title: "Finish now", symbol: "flag.checkered") { _ in
                if simulation.phase.isRunning { simulation.finish(outcome: simulation.outcome) }
            },
        ],
        exhibits: LabRunConcept.allCases.map { concept in
            RoundSpec.Exhibit(id: String(concept.rawValue.prefix(1)), title: concept.rawValue, summary: concept.summary,
                              designWidth: LabRound15Metrics.windowWidth, designHeight: LabRound15Metrics.windowHeight) { values in
                RunExhibit(concept: concept, values: values)
            }
        },
        exhibitTopic: ("Where does Run live?",
                       "Run a query in each window, let it succeed and fail, cancel one. Say in the note if you'd combine two.",
                       "1",
                       "The quiet glyph keeps Run a plain ▶ like its neighbours, in a capsule of its own, so changing it moves nothing else in the toolbar. The others add a second place to look (footer, tab, corner) or hide Run until it is running.")
    )
}

private struct RunExhibit: View {
    let concept: LabRunConcept
    let values: RoundValues
    private var simulation: LabRunSimulation { RunRound.simulation }

    var body: some View {
        Group {
            switch concept {
            case .quietGlyph:
                LabRunWindow(
                    editorCapsule: { LabRunQuietGlyph(simulation: simulation) },
                    activeTab: { LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: true) },
                    editorOverlay: { EmptyView() }, footerTrailing: { LabRunStatusPill() })
            case .footer:
                LabRunWindow(
                    editorCapsule: { LabRunEditorCapsule() },
                    activeTab: { LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: true) },
                    editorOverlay: { EmptyView() }, footerTrailing: { LabRunFooterPill(simulation: simulation) })
            case .editorCorner:
                LabRunCornerWindow(simulation: simulation)
            case .tab:
                LabRunWindow(
                    editorCapsule: { LabRunEditorCapsule() },
                    activeTab: { LabRunTab(simulation: simulation) },
                    editorOverlay: { EmptyView() }, footerTrailing: { LabRunStatusPill() })
            case .onlyWhileRunning:
                LabRunWindow(
                    editorCapsule: { LabRunEditorCapsule() },
                    activeTab: { LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: true) },
                    editorOverlay: { LabRunFloatingCapsule(simulation: simulation) },
                    footerTrailing: { LabRunStatusPill() }, gutterArrow: { simulation.start() })
            }
        }
        .onAppear { sync() }
        .onChange(of: values["outcome"]) { _, _ in sync() }
        .onChange(of: values["length"]) { _, _ in sync() }
        .animation((LabSpeed(rawValue: values["speed"]) ?? .standard).spring(), value: simulation.phase)
    }

    private func sync() {
        simulation.outcome = LabRunOutcome(rawValue: values["outcome"]) ?? .success
        simulation.length = LabRunLength(rawValue: values["length"]) ?? .quick
    }
}
