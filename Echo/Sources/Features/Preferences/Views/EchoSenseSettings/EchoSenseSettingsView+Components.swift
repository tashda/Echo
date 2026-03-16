import SwiftUI
import AppKit

// MARK: - Info Topic

enum EchoSenseInfoTopic: String, Identifiable, CaseIterable {
    case qualifiedTables
    case systemSchemas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qualifiedTables: return "Schema-qualified Insertion"
        case .systemSchemas: return "System Schemas"
        }
    }

    var message: String {
        switch self {
        case .qualifiedTables:
            return "Automatically inserts schema-qualified names (schema.table) when a completion knows the schema. Existing text is never rewritten, and column completions keep their current behaviour."
        case .systemSchemas:
            return "System schemas such as pg_catalog or information_schema contain internal objects. Enable this when you want to browse them in EchoSense; otherwise they stay hidden to reduce noise."
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
                .foregroundStyle(ColorTokens.Text.secondary)
                .popover(isPresented: $isPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
                    EchoSenseInfoPopover(topic: topic)
                }
            }
        } label: {
            Text(title)
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
            .padding(SpacingTokens.md)
            .frame(width: 300)
    }
}
