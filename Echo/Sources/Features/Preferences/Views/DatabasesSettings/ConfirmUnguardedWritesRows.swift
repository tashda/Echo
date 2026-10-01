import SwiftUI

/// Round 43.5 (PC0): the default for asking before an UPDATE or DELETE without WHERE, and the
/// connections that chose otherwise, each with its colour dot, so a per-connection value is never
/// hidden away from Settings.
struct ConfirmUnguardedWritesRows: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(EnvironmentState.self) private var environmentState

    private var overrides: [SavedConnection] {
        environmentState.connectionStore.connections.filter { $0.confirmUnguardedWrites != nil }
    }

    var body: some View {
        PropertyRow(
            title: "Confirm Unguarded Writes",
            subtitle: "UPDATE or DELETE without a WHERE",
            info: "Asks before a statement that changes every row it reaches runs. A connection can choose its own; those that do are listed here.",
            resetAction: projectStore.resetAction(\.confirmUnguardedWrites)
        ) {
            Toggle("", isOn: projectStore.globalSettingBinding(\.confirmUnguardedWrites))
                .labelsHidden()
                .toggleStyle(.switch)
        }
        ForEach(overrides) { connection in
            PropertyRow(title: connection.connectionName) {
                HStack(spacing: SpacingTokens.xs) {
                    Text(connection.confirmUnguardedWrites == true ? "Always asks" : "Never asks")
                        .foregroundStyle(ColorTokens.Text.secondary)
                    Circle().fill(connection.color).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                }
            }
        }
    }
}
