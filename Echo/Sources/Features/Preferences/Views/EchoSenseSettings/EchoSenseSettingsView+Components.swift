import SwiftUI
import AppKit

// MARK: - Info Topic

enum EchoSenseInfoTopic: String, Identifiable, CaseIterable {
    case qualifiedTables
    case systemSchemas
    case liveValidation
    case ghostText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qualifiedTables: return "Schema-qualified Insertion"
        case .systemSchemas: return "System Schemas"
        case .liveValidation: return "Live Query Validation"
        case .ghostText: return "Ghost Text"
        }
    }

    var message: String {
        switch self {
        case .qualifiedTables:
            return "Automatically inserts schema-qualified names (schema.table) when a completion knows the schema. Existing text is never rewritten, and column completions keep their current behaviour."
        case .systemSchemas:
            return "System schemas such as pg_catalog or information_schema contain internal objects. Enable this when you want to browse them in EchoSense; otherwise they stay hidden to reduce noise."
        case .ghostText:
            return "Shows the best suggestion as grey text after the cursor instead of the list; press Tab to accept it. The full list still opens with the EchoSense shortcut."
        case .liveValidation:
            return "Checks your SQL as you type for syntax errors and references to unknown tables, columns, or schemas. Only flags issues when the validator is confident — if metadata is incomplete, checks are silently skipped."
        }
    }
}

// MARK: - Support Views

struct EchoSenseToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let topic: EchoSenseInfoTopic

    var body: some View {
        PropertyRow(title: title, info: topic.message) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

struct EchoSenseInfoPopover: View {
    let topic: EchoSenseInfoTopic

    var body: some View {
        Text(topic.message)
            .font(TypographyTokens.standard)
            .foregroundStyle(ColorTokens.Text.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .floatingSurfaceContent(.medium)
    }
}
