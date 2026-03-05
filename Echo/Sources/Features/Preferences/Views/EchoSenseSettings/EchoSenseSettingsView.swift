import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct EchoSenseSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(NavigationStore.self) private var navigationStore
    @EnvironmentObject internal var appState: AppState
    @EnvironmentObject private var appearanceStore: AppearanceStore

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

                EchoSenseToggleRow(
                    title: "Enable Command + Period",
                    isOn: commandTriggerBinding,
                    topic: .commandTrigger
                )

                EchoSenseToggleRow(
                    title: "Enable Control + Space",
                    isOn: controlTriggerBinding,
                    topic: .controlTrigger
                )
            }

            Section("Dismissal") {
                Text(dismissalHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
