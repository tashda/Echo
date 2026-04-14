import SwiftUI

/// Tracks full back/forward navigation history for any `Hashable` state,
/// like a browser or Finder.
///
/// Call `push(_:)` when the user navigates to a new state. Use `goBack()`
/// and `goForward()` to traverse the history. Each returns the state to
/// restore, or `nil` if the stack is empty.
@Observable
@MainActor
final class NavigationHistory<State: Hashable>: Sendable {

    private var backStack: [State] = []
    private var forwardStack: [State] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Record a user-initiated navigation. The current state is pushed onto
    /// the back stack, and the forward stack is cleared.
    func push(_ currentState: State) {
        backStack.append(currentState)
        forwardStack.removeAll()
    }

    /// Pop the back stack. Returns the state to restore.
    /// The caller must pass the current state so it can be pushed onto
    /// the forward stack.
    func goBack(from currentState: State) -> State? {
        guard let target = backStack.popLast() else { return nil }
        forwardStack.append(currentState)
        return target
    }

    /// Pop the forward stack. Returns the state to restore.
    /// The caller must pass the current state so it can be pushed onto
    /// the back stack.
    func goForward(from currentState: State) -> State? {
        guard let target = forwardStack.popLast() else { return nil }
        backStack.append(currentState)
        return target
    }
}
