import Observation
import SwiftUI

/// The testing controls every specimen stage offers: appearance, card corners, motion speed,
/// Reduce Motion and Replay. One instance drives all specimens on a page.
@Observable @MainActor
final class LabStageSettings {
    /// One set of testing controls for every page, remembered between launches.
    static let shared = LabStageSettings()

    private struct Saved: Codable { var appearance: String; var corners: Double; var fast: Bool; var reduceMotion: Bool }

    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System", light = "Light", dark = "Dark"
        var id: String { rawValue }
        var scheme: ColorScheme? { self == .light ? .light : (self == .dark ? .dark : nil) }
    }

    var appearance: Appearance = .system { didSet { save() } }
    var cornerRadius = LayoutTokens.Workspace.cardCornerRadius { didSet { save() } }
    var fast = false { didSet { save() } }
    var reduceMotion = false { didSet { save() } }
    var replay = 0

    init() {
        if let saved: Saved = LabPrefs.load("stage", default: Optional<Saved>.none) {
            appearance = Appearance(rawValue: saved.appearance) ?? .system
            cornerRadius = CGFloat(saved.corners)
            fast = saved.fast
            reduceMotion = saved.reduceMotion
        }
    }

    private func save() {
        LabPrefs.save(Saved(appearance: appearance.rawValue, corners: Double(cornerRadius), fast: fast, reduceMotion: reduceMotion), key: "stage")
    }

    var motion: EchoMotion { EchoMotion(durationScale: fast ? 0.7 : 1, reduceMotion: reduceMotion) }
}

/// The bar of testing controls.
struct LabStageControlBar: View {
    @Bindable var settings: LabStageSettings

    var body: some View {
        HStack(spacing: SpacingTokens.md) {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(LabStageSettings.Appearance.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .labelsHidden()
            Picker("Card corners", selection: $settings.cornerRadius) {
                ForEach([10.0, 12, 16, 20, 26], id: \.self) { Text("Corners \(Int($0))").tag(CGFloat($0)) }
            }
            .labelsHidden()
            .frame(width: 130)
            Toggle("Fast", isOn: $settings.fast)
            Toggle("Reduce Motion", isOn: $settings.reduceMotion)
            Spacer()
            Button("Replay", systemImage: "arrow.counterclockwise") { settings.replay += 1 }
        }
        .controlSize(.small)
    }
}

/// The same testing controls, stacked, for a narrow column.
struct LabStageControlColumn: View {
    @Bindable var settings: LabStageSettings

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(LabStageSettings.Appearance.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            Picker("Card corners", selection: $settings.cornerRadius) {
                ForEach([10.0, 12, 16, 20, 26], id: \.self) { Text("Corners \(Int($0))").tag(CGFloat($0)) }
            }
            HStack {
                Toggle("Fast", isOn: $settings.fast)
                Toggle("Reduce Motion", isOn: $settings.reduceMotion)
            }
            Button { settings.replay += 1 } label: { Label("Replay", systemImage: "arrow.counterclockwise") }
                .buttonStyle(LabPillButtonStyle())
        }
        .controlSize(.small)
    }
}

extension View {
    /// Gives a specimen the stage's card corners, motion and appearance, and recreates it on Replay.
    func labStage(_ settings: LabStageSettings) -> some View {
        self
            .id(settings.replay)
            .environment(\.workspaceCardCornerRadius, settings.cornerRadius)
            .environment(\.echoMotion, settings.motion)
            .preferredColorScheme(settings.appearance.scheme)
    }
}
