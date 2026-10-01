import SwiftUI

/// One exhibit: the tab bar and the editor card with the toasts in its top-right corner (as in
/// Echo, 8pt in from the card's edges), and buttons under it to post events.
struct NTExhibit: View {
    let options: NTOptions

    @State private var simulation = NTSimulation()
    @State private var isStackHovered = false
    @Environment(\.echoMotion) private var motion

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            Label("Query 1", systemImage: "tablecells")
                .font(TypographyTokens.standard)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.xxs2)
                .background(ColorTokens.Workspace.card, in: .capsule)
                .padding(SpacingTokens.xxxs)
                .glassEffect(.regular, in: .capsule)
            editorCard
            postBar
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
        .onAppear {
            simulation.duration = options.duration.seconds
            simulation.post(.queryFailed)
            simulation.post(.connected)
        }
        .onChange(of: options.duration) { _, duration in simulation.duration = duration.seconds }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("select *")
            Text("from public.employees")
            Spacer(minLength: SpacingTokens.none)
        }
        .font(TypographyTokens.code)
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
        .overlay(alignment: .topTrailing) {
            stack.padding(LayoutTokens.Toast.inset)
        }
    }

    @ViewBuilder
    private var stack: some View {
        let toasts = simulation.toasts
        GlassEffectContainer(spacing: SpacingTokens.sm) {
            switch options.stacking {
            case .list:
                list(toasts)
            case .deck:
                if isStackHovered || toasts.count < 2 {
                    list(toasts)
                } else {
                    deck(toasts)
                }
            case .newestOnly:
                if let newest = toasts.first {
                    NTToastView(toast: newest, options: options, simulation: simulation, hiddenCount: toasts.count - 1)
                        .transition(options.arrival.transition)
                }
            }
        }
        .onHover { isStackHovered = $0 }
        .animation(motion.standard, value: simulation.toasts)
        .animation(motion.standard, value: simulation.hoveredID)
        .animation(motion.standard, value: isStackHovered)
    }

    private func list(_ toasts: [NTSimulation.Toast]) -> some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.xs) {
            ForEach(toasts) { toast in
                NTToastView(toast: toast, options: options, simulation: simulation)
                    .transition(options.arrival.transition)
            }
        }
    }

    /// S2: the newest in front, the others peeking out below it; hovering fans them out.
    private func deck(_ toasts: [NTSimulation.Toast]) -> some View {
        ZStack(alignment: .top) {
            ForEach(Array(toasts.enumerated().reversed()), id: \.element.id) { index, toast in
                NTToastView(toast: toast, options: options, simulation: simulation)
                    .scaleEffect(1 - CGFloat(index) * 0.05, anchor: .top)
                    .offset(y: CGFloat(index) * SpacingTokens.xs)
                    .opacity(index == 0 ? 1 : 0.7)
                    .allowsHitTesting(index == 0)
                    .transition(options.arrival.transition)
            }
        }
    }

    private var postBar: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button("Connected") { simulation.post(.connected) }
            Button("Query failed") { simulation.post(.queryFailed) }
            Button("Long error") { simulation.post(.backupFailed) }
            Button("Switched") { simulation.post(.switched) }
            Button("Same again") { simulation.repeatLatest() }
            Spacer(minLength: SpacingTokens.none)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
