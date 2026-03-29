import SwiftUI

struct TriggerEditorWindow: Scene {
    static let sceneID = "trigger-editor"
    private let coordinator = AppDirector.shared

    var body: some Scene {
        WindowGroup(id: Self.sceneID, for: TriggerEditorWindowValue.self) { $value in
            if let value {
                TriggerEditorWindowContent(windowValue: value)
                    .environment(coordinator.projectStore)
                    .environment(coordinator.connectionStore)
                    .environment(coordinator.navigationStore)
                    .environment(coordinator.tabStore)
                    .environment(coordinator.resultSpoolConfigCoordinator)
                    .environment(coordinator.diagramBuilder)
                    .environment(coordinator.navigationStore.navigationState)
                    .environment(coordinator.environmentState)
                    .environment(coordinator.appState)
                    .environment(coordinator.clipboardHistory)
                    .environment(coordinator.appearanceStore)
                    .environment(coordinator.notificationEngine)
                    .environment(coordinator.activityEngine)
            }
        }
        .defaultSize(width: 800, height: 540)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MARK: - Window Content

private struct TriggerEditorWindowContent: View {
    let windowValue: TriggerEditorWindowValue
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(ActivityEngine.self) private var activityEngine
    @Environment(\.dismiss) private var dismiss

    private var viewModel: TriggerEditorViewModel? {
        environmentState.triggerEditorViewModels[windowValue]
    }

    private var connectionSession: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(windowValue.connectionSessionID)
    }

    var body: some View {
        if let viewModel, let session = connectionSession {
            TriggerEditorView(viewModel: viewModel, session: session) {
                dismiss()
            }
            .onAppear {
                viewModel.activityEngine = activityEngine
            }
            .background(PropertiesWindowConfigurator())
            .preferredColorScheme(appearanceStore.effectiveColorScheme)
            .accentColor(appearanceStore.accentColor)
            .onChange(of: viewModel.didComplete) { _, completed in
                if completed { dismiss() }
            }
        } else {
            ContentUnavailableView(
                "Session Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The connection session is no longer active.")
            )
            .frame(minWidth: 600, minHeight: 400)
        }
    }
}
