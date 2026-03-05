import SwiftUI
import AppKit

// MARK: - Info Topic

enum EchoSenseInfoTopic: String, Identifiable, CaseIterable {
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
            return "Keeps the \u{2318} + . shortcut available as a manual EchoSense trigger even after you dismiss the popover. Turn it off if you rely on \u{2318} + . for another workflow."
        case .controlTrigger:
            return "Keeps Ctrl + Space available as an alternative manual trigger for EchoSense, mirroring common editor behaviour. Disable it if Ctrl + Space is bound to another action on your system."
        }
    }
}

// MARK: - Support Views

struct EchoSenseToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let topic: EchoSenseInfoTopic
    @State private var isPopoverPresented = false

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)

                Button(action: { isPopoverPresented.toggle() }) {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $isPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                    EchoSenseInfoPopover(topic: topic)
                }
            }
        } label: {
            Text(title)
        }
    }
}

struct EchoSenseAggressivenessRow: View {
    @Binding var selection: SQLCompletionAggressiveness
    @State private var isPopoverPresented = false

    private static let modeDescriptions: [(mode: SQLCompletionAggressiveness, summary: String)] = [
        (.focused, "Only clause-relevant entries"),
        (.balanced, "Mix with light fallbacks"),
        (.eager, "Full list, generous suggestions"),
    ]

    var body: some View {
        LabeledContent {
            HStack(spacing: SpacingTokens.xxs2) {
                Picker("", selection: $selection) {
                    ForEach(SQLCompletionAggressiveness.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Button(action: { isPopoverPresented.toggle() }) {
                    Image(systemName: "info.circle")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .popover(isPresented: $isPopoverPresented,
                         attachmentAnchor: .rect(.bounds),
                         arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        ForEach(Self.modeDescriptions, id: \.mode) { item in
                            HStack(alignment: .top, spacing: SpacingTokens.xs) {
                                Text(item.mode.displayName)
                                    .font(TypographyTokens.standard.weight(.semibold))
                                    .frame(width: 72, alignment: .leading)
                                Text(item.summary)
                                    .font(TypographyTokens.standard)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(SpacingTokens.md)
                    .frame(width: 320)
                }
            }
        } label: {
            Text("Suggestion aggressiveness")
        }
    }
}

struct EchoSenseInfoPopover: View {
    let topic: EchoSenseInfoTopic

    var body: some View {
        Text(topic.message)
            .font(TypographyTokens.standard)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(SpacingTokens.md)
            .frame(width: 300)
    }
}
