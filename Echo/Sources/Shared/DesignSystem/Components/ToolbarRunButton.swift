import SwiftUI

/// A shared toolbar button for user-initiated run/stop actions.
///
/// Used by Query Editor ("Run"/"Run Selection"/"Cancel") and SQL Agent Jobs ("Start Job"/"Stop Job").
/// Distinct from monitoring controls — this represents a discrete action with a defined lifecycle.
///
/// ## States
/// - **Idle**: `play.fill`, accent-colored — ready to execute.
/// - **Selection active** (query editor): `play.fill` with filled variant — indicates scoped execution.
/// - **Running**: `stop.fill`, error-colored — tap to cancel/stop.
/// - **Disabled**: Greyed-out play icon.
struct ToolbarRunButton: View {
    let isRunning: Bool
    let isDisabled: Bool
    let hasSelection: Bool
    let idleLabel: String
    let selectionLabel: String
    let runningLabel: String
    let action: () -> Void

    init(
        isRunning: Bool,
        isDisabled: Bool = false,
        hasSelection: Bool = false,
        idleLabel: String = "Run",
        selectionLabel: String = "Run Selection",
        runningLabel: String = "Cancel",
        action: @escaping () -> Void
    ) {
        self.isRunning = isRunning
        self.isDisabled = isDisabled
        self.hasSelection = hasSelection
        self.idleLabel = idleLabel
        self.selectionLabel = selectionLabel
        self.runningLabel = runningLabel
        self.action = action
    }

    private var currentIcon: String {
        isRunning ? "stop.fill" : "play.fill"
    }

    private var currentLabel: String {
        if isRunning { return runningLabel }
        return hasSelection ? selectionLabel : idleLabel
    }

    private var iconColor: Color {
        if isRunning { return ColorTokens.Status.error }
        if isDisabled { return ColorTokens.Text.tertiary }
        return hasSelection ? ColorTokens.accent : ColorTokens.Text.primary
    }

    var body: some View {
        Button(action: action) {
            Label(currentLabel, systemImage: currentIcon)
                .foregroundStyle(iconColor)
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(!isRunning && isDisabled)
        .help(currentLabel)
        .labelStyle(.iconOnly)
        .accessibilityLabel(currentLabel)
    }
}
