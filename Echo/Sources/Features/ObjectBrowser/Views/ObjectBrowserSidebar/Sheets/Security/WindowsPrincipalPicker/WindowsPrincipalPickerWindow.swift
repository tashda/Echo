import SwiftUI
import ActiveDirectory

/// Movable, resizable window scene for browsing Active Directory. Unlike a
/// modal sheet, the user can drag this off to one side, resize it, and keep
/// it open across multiple Login/User editor sessions.
struct WindowsPrincipalPickerWindow: Scene {
    static let sceneID = "windows-principal-picker"
    private let coordinator = AppDirector.shared

    var body: some Scene {
        WindowGroup(id: Self.sceneID, for: WindowsPrincipalPickerWindowValue.self) { $value in
            if let value {
                WindowsPrincipalPickerWindowContent(windowValue: value)
                    .environment(coordinator.environmentState)
                    .environment(coordinator.appearanceStore)
            }
        }
        .defaultSize(width: 920, height: 600)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

private struct WindowsPrincipalPickerWindowContent: View {
    let windowValue: WindowsPrincipalPickerWindowValue
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(\.dismiss) private var dismiss

    private var viewModel: WindowsPrincipalPickerViewModel? {
        environmentState.windowsPrincipalPickerViewModels[windowValue]
    }

    var body: some View {
        Group {
            if let viewModel {
                WindowsPrincipalPickerSheet(
                    viewModel: viewModel,
                    onConfirm: { principals in
                        let name = principals.first.map { viewModel.sqlServerAccountName(for: $0) }
                        environmentState.completeWindowsPrincipalPickerWindow(
                            value: windowValue,
                            accountName: name
                        )
                        dismiss()
                    },
                    onCancel: {
                        environmentState.completeWindowsPrincipalPickerWindow(
                            value: windowValue,
                            accountName: nil
                        )
                        dismiss()
                    }
                )
            } else {
                ContentUnavailableView(
                    "Picker session unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This Browse Active Directory window can no longer reach its session. Close this window and try again.")
                )
                .frame(minWidth: 680, minHeight: 480)
            }
        }
        .preferredColorScheme(appearanceStore.effectiveColorScheme)
        .accentColor(appearanceStore.accentColor)
        .onDisappear {
            // Best-effort cleanup if the window is dismissed without going
            // through the Cancel/OK paths (e.g. red close button).
            environmentState.completeWindowsPrincipalPickerWindow(
                value: windowValue,
                accountName: nil
            )
        }
    }
}
