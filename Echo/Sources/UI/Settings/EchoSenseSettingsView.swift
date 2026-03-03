import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct EchoSenseSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    // Toggle: Include SQL keywords in EchoSense suggestions.
    private var suggestKeywordsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestKeywords },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestKeywords != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestKeywords = newValue } }
            }
        )
    }

    // Toggle: Show inline keyword previews while typing.
    private var inlineKeywordPreviewBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorEnableInlineSuggestions },
            set: { newValue in
                guard appModel.globalSettings.editorEnableInlineSuggestions != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorEnableInlineSuggestions = newValue } }
            }
        )
    }

    // Toggle: Suggest SQL functions in completions.
    private var suggestFunctionsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestFunctions },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestFunctions != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestFunctions = newValue } }
            }
        )
    }

    // Toggle: Suggest saved snippets in completions.
    private var suggestSnippetsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestSnippets },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestSnippets != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestSnippets = newValue } }
            }
        )
    }

    // Toggle: Qualify table completions with schema names.
    private var qualifyTablesBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorQualifyTableCompletions },
            set: { newValue in
                guard appModel.globalSettings.editorQualifyTableCompletions != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorQualifyTableCompletions = newValue } }
            }
        )
    }

    // Toggle: Boost suggestions using previously accepted history.
    private var suggestHistoryBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestHistory },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestHistory != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestHistory = newValue } }
            }
        )
    }

    // Toggle: Suggest JOIN helpers based on schema relationships.
    private var suggestJoinsBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorSuggestJoins },
            set: { newValue in
                guard appModel.globalSettings.editorSuggestJoins != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorSuggestJoins = newValue } }
            }
        )
    }

    private var aggressivenessBinding: Binding<SQLCompletionAggressiveness> {
        Binding(
            get: { appModel.globalSettings.editorCompletionAggressiveness },
            set: { newValue in
                guard appModel.globalSettings.editorCompletionAggressiveness != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorCompletionAggressiveness = newValue } }
            }
        )
    }

    // Toggle: Include system schemas in EchoSense suggestions.
    private var showSystemSchemasBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorShowSystemSchemas },
            set: { newValue in
                guard appModel.globalSettings.editorShowSystemSchemas != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorShowSystemSchemas = newValue } }
            }
        )
    }

    // Toggle: Allow Command + Period to trigger suggestions.
    private var commandTriggerBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorAllowCommandPeriodTrigger },
            set: { newValue in
                guard appModel.globalSettings.editorAllowCommandPeriodTrigger != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorAllowCommandPeriodTrigger = newValue } }
            }
        )
    }

    // Toggle: Allow Control + Space to trigger suggestions.
    private var controlTriggerBinding: Binding<Bool> {
        Binding(
            get: { appModel.globalSettings.editorAllowControlSpaceTrigger },
            set: { newValue in
                guard appModel.globalSettings.editorAllowControlSpaceTrigger != newValue else { return }
                Task { await appModel.updateGlobalEditorDisplay { $0.editorAllowControlSpaceTrigger = newValue } }
            }
        )
    }

    private var dismissalHint: String {
        let triggers: [String] = [
            appState.sqlEditorDisplay.allowCommandPeriodTrigger ? "⌘ + ." : nil,
            appState.sqlEditorDisplay.allowControlSpaceTrigger ? "Ctrl + Space" : nil
        ].compactMap { $0 }

        let triggerText: String
        switch triggers.count {
        case 0:
            triggerText = "the manual trigger"
        case 1:
            triggerText = triggers[0]
        default:
            let head = triggers.dropLast().joined(separator: ", ")
            triggerText = head + " or " + triggers.last!
        }

        let suffix = appState.sqlEditorDisplay.autoCompletionEnabled ? "" : " EchoSense stays off until you manually request it."
        return "Dismiss the popover to suspend automatic suggestions temporarily. Use \(triggerText) to bring them back instantly.\(suffix)"
    }

    var body: some View {
        Form {
            Section("Suggestions") {
                ToggleRow(
                    title: "Keywords",
                    isOn: suggestKeywordsBinding,
                    topic: .keywords
                )

                ToggleRow(
                    title: "Inline keyword preview",
                    isOn: inlineKeywordPreviewBinding,
                    topic: .inlineKeywords
                )
                .disabled(!appState.sqlEditorDisplay.autoCompletionEnabled)

                ToggleRow(
                    title: "Functions",
                    isOn: suggestFunctionsBinding,
                    topic: .functions
                )

                ToggleRow(
                    title: "Snippets",
                    isOn: suggestSnippetsBinding,
                    topic: .snippets
                )

                ToggleRow(
                    title: "Join helpers",
                    isOn: suggestJoinsBinding,
                    topic: .joins
                )

                ToggleRow(
                    title: "History boosting",
                    isOn: suggestHistoryBinding,
                    topic: .history
                )
            }

            Section("Insertion") {
                ToggleRow(
                    title: "Qualify table completions",
                    isOn: qualifyTablesBinding,
                    topic: .qualifiedTables
                )

                ToggleRow(
                    title: "Show system schemas",
                    isOn: showSystemSchemasBinding,
                    topic: .systemSchemas
                )
            }

            Section("Behaviour") {
                AggressivenessRow(
                    selection: aggressivenessBinding
                )

                ToggleRow(
                    title: "Enable Command + Period",
                    isOn: commandTriggerBinding,
                    topic: .commandTrigger
                )

                ToggleRow(
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

private enum InfoTopic: String, Identifiable, CaseIterable {
    case keywords
    case inlineKeywords
    case functions
    case snippets
    case joins
    case qualifiedTables
    case history
    case aggressiveness
    case systemSchemas
    case commandTrigger
    case controlTrigger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keywords: return "Keyword Suggestions"
        case .inlineKeywords: return "Inline Keyword Preview"
        case .functions: return "Function Suggestions"
        case .snippets: return "Snippet Templates"
        case .joins: return "Join Helpers"
        case .qualifiedTables: return "Schema-qualified Insertion"
        case .history: return "Recent Selections"
        case .aggressiveness: return "Suggestion Aggressiveness"
        case .systemSchemas: return "System Schemas"
        case .commandTrigger: return "Command + Period"
        case .controlTrigger: return "Control + Space"
        }
    }

    var message: String {
        switch self {
        case .keywords:
            return "When enabled, the EchoSense popover lists SQL keywords that match the current clause. Turning this off hides keyword entries, but it will not remove snippets or objects that explicitly match what you type."
        case .inlineKeywords:
            return "Shows the remainder of the next SQL keyword as faint inline text (for example FROM after SELECT *). Disabling this keeps keyword rows in the popover intact but removes the ghosted preview inside the editor."
        case .functions:
            return "Shows built-in and database-specific functions ranked by context. Disabling this leaves typed function names untouched and does not affect user-defined functions you type manually."
        case .snippets:
            return "Provides templated completions (for example CASE, JSON helpers) with tab-stop placeholders. When disabled, no snippet rows appear, but regular keywords and objects remain available."
        case .joins:
            return "Offers ON-clause suggestions derived from foreign keys and recent join history. Turning it off keeps JOIN keywords and table suggestions, but removes the one-click join conditions."
        case .qualifiedTables:
            return "Automatically inserts schema-qualified names (schema.table) when a completion knows the schema. Existing text is never rewritten, and column completions keep their current behaviour."
        case .history:
            return "Remember tables, columns, and joins you accept so the engine can boost them later. History stays on your Mac and does not sync or leave the application."
        case .aggressiveness:
            return "Focused shows only clause-relevant entries, Balanced keeps a mix with light fallbacks, and Eager keeps the full list. Switch modes depending on whether you prefer concise or generous suggestions."
        case .systemSchemas:
            return "System schemas such as pg_catalog or information_schema contain internal objects. Enable this when you want to browse them in EchoSense; otherwise they stay hidden to reduce noise."
        case .commandTrigger:
            return "Keeps the ⌘ + . shortcut available as a manual EchoSense trigger even after you dismiss the popover. Turn it off if you rely on ⌘ + . for another workflow."
        case .controlTrigger:
            return "Keeps Ctrl + Space available as an alternative manual trigger for EchoSense, mirroring common editor behaviour. Disable it if Ctrl + Space is bound to another action on your system."
        }
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let topic: InfoTopic
    @State private var isPopoverPresented = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)

            Spacer(minLength: 8)

            Button(action: { isPopoverPresented.toggle() }) {
                Image(systemName: "info.circle")
                    .imageScale(.medium)
                    .font(.system(size: 13, weight: .regular))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $isPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                InfoPopover(topic: topic)
            }
        }
    }
}

private struct AggressivenessRow: View {
    @Binding var selection: SQLCompletionAggressiveness
    @State private var isPopoverPresented = false

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Picker("", selection: $selection) {
                    ForEach(SQLCompletionAggressiveness.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Button(action: { isPopoverPresented.toggle() }) {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                        .font(.system(size: 13, weight: .regular))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $isPopoverPresented,
                         attachmentAnchor: .rect(.bounds),
                         arrowEdge: .trailing) {
                    InfoPopover(topic: .aggressiveness)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } label: {
            Text("Suggestion aggressiveness")
        }
    }
}

private struct InfoPopover: View {
    let topic: InfoTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(topic.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(topic.message)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: preferredWidth)
    }

    private var preferredWidth: CGFloat {
        let padding: CGFloat = 32
        let minWidth: CGFloat = 320
        let maxWidth: CGFloat = 440
        let contentLimit = maxWidth - padding

        let titleWidth = measuredWidth(for: topic.title, font: platformFont(size: 15, weight: PlatformFont.Weight.semibold), limit: contentLimit)
        let messageWidth = measuredWidth(for: topic.message, font: platformFont(size: 13), limit: contentLimit)
        let contentWidth = max(titleWidth, messageWidth)
        return min(maxWidth, max(minWidth, contentWidth + padding))
    }

    private func platformFont(size: CGFloat, weight: PlatformFont.Weight = PlatformFont.Weight.regular) -> PlatformFont {
#if os(macOS)
        NSFont.systemFont(ofSize: size, weight: weight)
#else
        UIFont.systemFont(ofSize: size, weight: weight)
#endif
    }

    private func measuredWidth(for text: String, font: PlatformFont, limit: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let constraint = CGSize(width: limit, height: .greatestFiniteMagnitude)
#if os(macOS)
        let rect = NSAttributedString(string: text, attributes: [.font: font])
            .boundingRect(with: constraint, options: [.usesLineFragmentOrigin, .usesFontLeading])
#else
        let rect = (text as NSString).boundingRect(with: constraint, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
#endif
        return ceil(rect.width)
    }
}
