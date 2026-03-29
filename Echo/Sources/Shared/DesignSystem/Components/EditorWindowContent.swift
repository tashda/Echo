import SwiftUI

/// Shared window content wrapper for all editor windows (Function Editor, Role Editor, etc.).
/// Handles environment injection, view model lookup, and standard error state.
///
/// Usage in a WindowGroup scene body:
/// ```
/// EditorWindowContent(windowValue: value) { viewModel, session in
///     MyEditorView(viewModel: viewModel, session: session)
/// }
/// ```
struct EditorWindowContent<Value: Hashable, ViewModel: AnyObject, Content: View>: View {
    let windowValue: Value
    let viewModelLookup: (EnvironmentState, Value) -> ViewModel?
    let sessionLookup: (EnvironmentState, Value) -> ConnectionSession?
    @ViewBuilder let content: (ViewModel, ConnectionSession) -> Content

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let viewModel = viewModelLookup(environmentState, windowValue),
           let session = sessionLookup(environmentState, windowValue) {
            content(viewModel, session)
                .background(PropertiesWindowConfigurator())
                .preferredColorScheme(appearanceStore.effectiveColorScheme)
                .accentColor(appearanceStore.accentColor)
        } else {
            ContentUnavailableView(
                "Session Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The connection session is no longer active.")
            )
            .frame(minWidth: 680, minHeight: 480)
        }
    }
}
