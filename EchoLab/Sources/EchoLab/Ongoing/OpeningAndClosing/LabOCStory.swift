import SwiftUI

/// The story as an exhibit: the mini window, and under it the four steps to play one at a time or
/// all together. A change in the controls replays the step you are on.
struct LabOCStory: View {
    let look: LabOCLook
    var pulse = ""

    @Environment(\.echoMotion) private var motion
    @State private var scene = LabOCScene()

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            LabOCWindow(scene: scene)
            steps
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            scene.look = look
            scene.motion = motion
            scene.play(.launch)
        }
        .onChange(of: look) { _, new in
            scene.look = new
            scene.play(scene.step)
        }
        .onChange(of: motion) { _, new in scene.motion = new }
        .onChange(of: pulse) { _, _ in scene.playAll() }
    }

    private var steps: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button { scene.playAll() } label: { Label("Play the story", systemImage: "play.fill") }
                .buttonStyle(.borderedProminent)
            ForEach(LabOCStep.allCases, id: \.self) { step in
                Button { scene.play(step) } label: { Label(step.title, systemImage: step.symbol) }
                    .buttonStyle(.bordered)
                    .tint(scene.step == step ? Color.accentColor : nil)
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .controlSize(.small)
    }
}

/// The four marks side by side, each replayed by a click or by the round's Replay action.
struct LabOCMarksExhibit: View {
    let slow: Bool
    let pulse: String

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.md) {
            ForEach(LabOCMarkStyle.allCases, id: \.self) { style in
                LabOCMarkCell(style: style, slow: slow, pulse: pulse)
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas)
    }
}

private struct LabOCMarkCell: View {
    let style: LabOCMarkStyle
    let slow: Bool
    let pulse: String

    @State private var phase: LabOCMarkPhase = .hidden

    var body: some View {
        Button(action: play) {
            VStack(spacing: SpacingTokens.sm) {
                Spacer(minLength: SpacingTokens.none)
                VStack(spacing: SpacingTokens.sm) {
                    LabOCMark(phase: phase, ghosts: style == .ghosts, width: 96, slow: slow)
                    if style.showsName {
                        Text("Echo").font(.system(size: LayoutTokens.Welcome.titleSize * 0.8, weight: .bold)).foregroundStyle(ColorTokens.Text.primary)
                    }
                }
                Spacer(minLength: SpacingTokens.none)
                Text(style.rawValue)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: SpacingTokens.xxl, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear(perform: play)
        .onChange(of: pulse) { _, _ in play() }
        .onChange(of: slow) { _, _ in play() }
        .help("Replay")
    }

    private func play() {
        phase = style.animates ? .hidden : .resting
        guard style.animates else { return }
        Task(name: "lab-mark-replay") { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            phase = .playing(Date())
        }
    }
}
