#if DEBUG
import SwiftUI

// MARK: - 4 · In the tab

struct LabRunTab: View {
    let simulation: LabRunSimulation

    @State private var isHovering = false

    var body: some View {
        LabRunTabLabel(
            isActive: true,
            icon: {
                Button(action: simulation.toggle) { icon }
                    .buttonStyle(.plain)
                    .help(simulation.phase.isRunning ? "Cancel (⌥⌘.)" : "Run (⌘↩)")
            },
            title: "Query 1",
            subtitle: { subtitle }
        )
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var icon: some View {
        switch simulation.phase {
        case .running:
            if isHovering {
                Image(systemName: "stop.fill").foregroundStyle(ColorTokens.Status.error)
            } else {
                ProgressView().controlSize(.mini)
            }
        case .succeeded:
            Image(systemName: "checkmark").foregroundStyle(ColorTokens.Status.success)
        case .failed:
            Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(ColorTokens.Status.error)
        default:
            Image(systemName: isHovering ? "play.fill" : "doc.text")
                .foregroundStyle(isHovering ? ColorTokens.accent : ColorTokens.Text.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        switch simulation.phase {
        case .running(let started):
            LabRunTimer(started: started)
        case .succeeded(let rows, _):
            Text("\(rows.formatted()) rows").foregroundStyle(ColorTokens.Status.success)
        case .failed:
            Text("Failed").foregroundStyle(ColorTokens.Status.error)
        default:
            Text("employees")
        }
    }
}

// MARK: - 5 · Only while running

struct LabRunFloatingCapsule: View {
    let simulation: LabRunSimulation

    var body: some View {
        VStack {
            Spacer(minLength: SpacingTokens.none)
            if simulation.phase != .idle {
                Button(action: simulation.cancel) {
                    content
                        .font(TypographyTokens.detail.weight(.medium))
                        .padding(.horizontal, SpacingTokens.sm)
                        .frame(height: LabRound15Metrics.footerHeight + SpacingTokens.xxs)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .disabled(!simulation.phase.isRunning)
                .glassEffect(.regular.interactive(), in: .capsule)
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.bottom, LabRound15Metrics.footerHeight + SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch simulation.phase {
        case .running(let started):
            HStack(spacing: SpacingTokens.xxs2) {
                ProgressView().controlSize(.mini)
                Text("Running")
                LabRunTimer(started: started).foregroundStyle(ColorTokens.Text.secondary)
                Image(systemName: "stop.fill").foregroundStyle(ColorTokens.Status.error)
            }
        default:
            LabRunResultLabel(phase: simulation.phase)
        }
    }
}
#endif
