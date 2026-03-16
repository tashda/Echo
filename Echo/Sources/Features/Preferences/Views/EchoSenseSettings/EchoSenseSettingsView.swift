import SwiftUI
import AppKit

struct EchoSenseSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(AppState.self) internal var appState
    @Environment(AppearanceStore.self) private var appearanceStore

    var body: some View {
        Form {
            Section("Insertion") {
                EchoSenseToggleRow(
                    title: "Qualify table completions",
                    isOn: qualifyTablesBinding,
                    topic: .qualifiedTables
                )

                EchoSenseToggleRow(
                    title: "Show system schemas",
                    isOn: showSystemSchemasBinding,
                    topic: .systemSchemas
                )
            }

            Section("Shortcuts") {
                LabeledContent {
                    Button {
                        NotificationCenter.default.post(
                            name: .openSettingsSection,
                            object: "keyboardShortcuts",
                            userInfo: ["highlightSection": "EchoSense"]
                        )
                    } label: {
                        HStack(spacing: SpacingTokens.xxs) {
                            Text("Keyboard Shortcuts")
                            Image(systemName: "arrow.forward")
                                .font(TypographyTokens.detail)
                        }
                    }
                    .buttonStyle(.bordered)
                } label: {
                    Text("Trigger shortcuts")
                }
            }

        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
