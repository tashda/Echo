import SwiftUI

// MARK: - Simple single-value tracking

/// Adds back/forward toolbar buttons and automatically tracks changes to
/// a single selection binding.
///
/// Usage:
/// ```swift
/// @State private var selection: MyType?
/// @State private var navHistory = NavigationHistory<MyType>()
///
/// NavigationSplitView { ... } detail: { ... }
///     .navigationHistoryToolbar($selection, history: navHistory)
/// ```
struct NavigationHistoryToolbar<Value: Hashable>: ViewModifier {
    @Binding var selection: Value?
    @Bindable var history: NavigationHistory<Value>
    @State private var isRestoring = false

    func body(content: Content) -> some View {
        content
            .onChange(of: selection) { oldValue, _ in
                guard !isRestoring, let oldValue else { return }
                history.push(oldValue)
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ToolbarNavigationButtons(
                        canGoBack: history.canGoBack,
                        canGoForward: history.canGoForward,
                        onBack: {
                            guard let current = selection,
                                  let target = history.goBack(from: current) else { return }
                            isRestoring = true
                            selection = target
                            DispatchQueue.main.async { isRestoring = false }
                        },
                        onForward: {
                            guard let current = selection,
                                  let target = history.goForward(from: current) else { return }
                            isRestoring = true
                            selection = target
                            DispatchQueue.main.async { isRestoring = false }
                        }
                    )
                }
            }
    }
}

// MARK: - Composite state tracking

/// Adds back/forward toolbar buttons with custom snapshot/restore logic
/// for views that track multiple pieces of state (e.g. section + sub-tab).
///
/// Usage:
/// ```swift
/// @State private var navHistory = NavigationHistory<MyDestination>()
///
/// .compositeNavigationHistoryToolbar(
///     history: navHistory,
///     snapshot: { currentDestination },
///     restore: { restore($0) }
/// )
/// ```
///
/// The view is responsible for calling `navHistory.push(snapshot())`
/// in its own `onChange` handlers, guarded by the `isRestoringNavigation`
/// environment value.
struct CompositeNavigationHistoryToolbar<State: Hashable>: ViewModifier {
    @Bindable var history: NavigationHistory<State>
    var snapshot: () -> State
    var restore: (State) -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ToolbarNavigationButtons(
                        canGoBack: history.canGoBack,
                        canGoForward: history.canGoForward,
                        onBack: {
                            guard let target = history.goBack(from: snapshot()) else { return }
                            restore(target)
                        },
                        onForward: {
                            guard let target = history.goForward(from: snapshot()) else { return }
                            restore(target)
                        }
                    )
                }
            }
    }
}

// MARK: - View extensions

extension View {
    /// Adds Finder-style back/forward toolbar buttons that track a single
    /// selection value.
    func navigationHistoryToolbar<Value: Hashable>(
        _ selection: Binding<Value?>,
        history: NavigationHistory<Value>
    ) -> some View {
        modifier(NavigationHistoryToolbar(
            selection: selection,
            history: history
        ))
    }

    /// Adds Finder-style back/forward toolbar buttons with custom
    /// snapshot/restore for composite navigation state.
    func compositeNavigationHistoryToolbar<State: Hashable>(
        history: NavigationHistory<State>,
        snapshot: @escaping () -> State,
        restore: @escaping (State) -> Void
    ) -> some View {
        modifier(CompositeNavigationHistoryToolbar(
            history: history,
            snapshot: snapshot,
            restore: restore
        ))
    }
}
