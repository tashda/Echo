import Observation
import SwiftUI

/// The testing controls every specimen stage offers: appearance, card corners, motion speed,
/// Reduce Motion and Replay. One instance drives all specimens on a page.
@Observable @MainActor
final class LabStageSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system = "System", light = "Light", dark = "Dark"
        var id: String { rawValue }
        var scheme: ColorScheme? { self == .light ? .light : (self == .dark ? .dark : nil) }
    }

    var appearance: Appearance = .system
    var cornerRadius = LayoutTokens.Workspace.cardCornerRadius
    var fast = false
    var reduceMotion = false
    var replay = 0

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

/// Scales a specimen designed for a fixed size down to the width it is given, so nothing ever
/// needs a horizontal scroll. It never scales up.
struct LabFitToWidth<Content: View>: View {
    let designWidth: CGFloat
    let designHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var width: CGFloat = 0

    private var scale: CGFloat { width > 0 ? min(1, width / designWidth) : 1 }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: designHeight * scale)
            .background(GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size.width, initial: true) { _, new in width = new }
            })
            .overlay(alignment: .top) {
                content
                    .frame(width: designWidth, height: designHeight)
                    .scaleEffect(scale, anchor: .top)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
    }
}

/// Like `LabFitToWidth`, for content of unknown height: it is laid out at `designWidth`, then
/// measured, and scaled down to the width it is given.
struct LabFitToWidthAuto<Content: View>: View {
    let designWidth: CGFloat
    @ViewBuilder var content: Content
    @State private var width: CGFloat = 0
    @State private var measured = CGSize(width: 1, height: 1)

    private var scale: CGFloat { width > 0 ? min(1, width / designWidth) : 1 }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: max(measured.height, 1) * scale)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
            .overlay(alignment: .topLeading) {
                content
                    .frame(width: designWidth, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGSize.self, of: { $0.size }) { measured = $0 }
                    .scaleEffect(scale, anchor: .topLeading)
            }
    }
}
