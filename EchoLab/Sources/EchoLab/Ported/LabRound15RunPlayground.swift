import SwiftUI

/// Round 15: five places for Run, side by side on one simulated query, so every state and the
/// moves between them can be compared: idle, running with its timer, the result, and back.
struct LabRound15RunPlayground: View {
    @State private var simulation = LabRunSimulation()
    @State private var speed: LabSpeed = .standard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LabStage(title: "Run · five places, one query") {
            Button(simulation.phase.isRunning ? "Cancel" : "Run (⌘↩)") { simulation.toggle() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Finish now") { simulation.finish(outcome: simulation.outcome) }
                .disabled(!simulation.phase.isRunning)
            LabPicker(title: "The query", selection: Bindable(simulation).outcome, options: LabRunOutcome.allCases)
            LabPicker(title: "Takes", selection: Bindable(simulation).length, options: LabRunLength.allCases)
            LabPicker(title: "Speed", selection: $speed, options: LabSpeed.allCases)
        } content: {
            LazyVGrid(columns: [GridItem(.fixed(LabRound15Metrics.windowWidth)), GridItem(.fixed(LabRound15Metrics.windowWidth))],
                      alignment: .leading, spacing: SpacingTokens.lg) {
                ForEach(LabRunConcept.allCases) { concept in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                        Text(concept.rawValue).font(TypographyTokens.headline)
                        Text(concept.summary)
                            .font(TypographyTokens.callout)
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        window(for: concept)
                    }
                    .frame(width: LabRound15Metrics.windowWidth, alignment: .leading)
                }
            }
            .padding(SpacingTokens.md)
            .animation(speed.spring(reduceMotion: reduceMotion), value: simulation.phase)
        }
    }

    @ViewBuilder
    private func window(for concept: LabRunConcept) -> some View {
        switch concept {
        case .quietGlyph:
            LabRunWindow(
                editorCapsule: { LabRunQuietGlyph(simulation: simulation) },
                activeTab: { LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: true) },
                editorOverlay: { EmptyView() },
                footerTrailing: { LabRunStatusPill() }
            )
        case .footer:
            LabRunWindow(
                editorCapsule: { LabRunEditorCapsule() },
                activeTab: { LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: true) },
                editorOverlay: { EmptyView() },
                footerTrailing: { LabRunFooterPill(simulation: simulation) }
            )
        case .editorCorner:
            LabRunCornerWindow(simulation: simulation)
        case .tab:
            LabRunWindow(
                editorCapsule: { LabRunEditorCapsule() },
                activeTab: { LabRunTab(simulation: simulation) },
                editorOverlay: { EmptyView() },
                footerTrailing: { LabRunStatusPill() }
            )
        case .onlyWhileRunning:
            LabRunWindow(
                editorCapsule: { LabRunEditorCapsule() },
                activeTab: { LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: true) },
                editorOverlay: { LabRunFloatingCapsule(simulation: simulation) },
                footerTrailing: { LabRunStatusPill() },
                gutterArrow: { simulation.start() }
            )
        }
    }
}

/// Concept 3 needs the pointer over the editor card to show its button.
private struct LabRunCornerWindow: View {
    let simulation: LabRunSimulation
    @State private var isHovering = false

    var body: some View {
        LabRunWindow(
            editorCapsule: { LabRunEditorCapsule() },
            activeTab: { LabRunTabLabel(icon: "doc.text", title: "Query 1", subtitle: "employees", isActive: true) },
            editorOverlay: {
                LabRunCornerButton(simulation: simulation, isHoveringCard: isHovering)
                    .contentShape(Rectangle())
                    .onHover { isHovering = $0 }
            },
            footerTrailing: { LabRunStatusPill() }
        )
    }
}

/// The footer's status pill as Echo has it, for the concepts that leave the footer alone.
struct LabRunStatusPill: View {
    var body: some View {
        Label("Ready", systemImage: "circle.fill")
            .labelStyle(.titleAndIcon)
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LabRound15Metrics.footerHeight)
            .glassEffect(.regular, in: .capsule)
    }
}
