import SwiftUI
import AppKit

struct EchoSenseSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(AppState.self) internal var appState
    @Environment(AppearanceStore.self) private var appearanceStore

    var body: some View {
        Form {
            Section("Suggestions") {
                EchoSenseToggleRow(
                    title: "Keywords",
                    isOn: suggestKeywordsBinding,
                    topic: .keywords
                )

                EchoSenseToggleRow(
                    title: "Inline keyword preview",
                    isOn: inlineKeywordPreviewBinding,
                    topic: .inlineKeywords
                )
                .disabled(!appState.sqlEditorDisplay.autoCompletionEnabled)

                EchoSenseToggleRow(
                    title: "Functions",
                    isOn: suggestFunctionsBinding,
                    topic: .functions
                )

                EchoSenseToggleRow(
                    title: "Snippets",
                    isOn: suggestSnippetsBinding,
                    topic: .snippets
                )

                EchoSenseToggleRow(
                    title: "Join helpers",
                    isOn: suggestJoinsBinding,
                    topic: .joins
                )

                EchoSenseToggleRow(
                    title: "History boosting",
                    isOn: suggestHistoryBinding,
                    topic: .history
                )
            }

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

            Section("Behaviour") {
                EchoSenseAggressivenessRow(
                    selection: aggressivenessBinding
                )

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
