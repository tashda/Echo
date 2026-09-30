import SwiftUI

/// The stage a specimen sits on, with the controls that matter for testing anything in Echo:
/// appearance, card corners, motion speed and Reduce Motion, and Replay.
struct AsBuiltStage: View {
    let page: AsBuiltPage

    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System", light = "Light", dark = "Dark"
        var id: String { rawValue }
        var scheme: ColorScheme? { self == .light ? .light : (self == .dark ? .dark : nil) }
    }

    @State private var appearance: Appearance = .system
    @State private var cornerRadius = LayoutTokens.Workspace.cardCornerRadius
    @State private var fast = false
    @State private var reduceMotion = false
    @State private var replay = 0

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            controlBar
            specimenStage
            if let controls = page.controls {
                controls()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: SpacingTokens.md) {
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .labelsHidden()
            Picker("Card corners", selection: $cornerRadius) {
                ForEach([10.0, 12, 16, 20, 26], id: \.self) { Text("Corners \(Int($0))").tag(CGFloat($0)) }
            }
            .labelsHidden()
            .frame(width: 130)
            Toggle("Fast", isOn: $fast)
            Toggle("Reduce Motion", isOn: $reduceMotion)
            Spacer()
            Button("Replay", systemImage: "arrow.counterclockwise") { replay += 1 }
        }
        .controlSize(.small)
    }

    private var specimenStage: some View {
        page.specimen()
            .id(replay)
            .environment(\.workspaceCardCornerRadius, cornerRadius)
            .environment(\.echoMotion, EchoMotion(durationScale: fast ? 0.7 : 1, reduceMotion: reduceMotion))
            .frame(maxWidth: .infinity)
            .frame(height: page.stageHeight)
            .background(ColorTokens.Workspace.canvas)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ColorTokens.Workspace.cardEdge.opacity(0.5), lineWidth: 0.5))
            .preferredColorScheme(appearance.scheme)
    }
}
