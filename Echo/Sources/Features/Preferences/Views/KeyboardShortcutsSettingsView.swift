import SwiftUI
import Foundation

struct KeyboardShortcutsSettingsView: View {
    private let sections = ShortcutSectionData.defaults

    var body: some View {
        Form {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        ShortcutRowView(item: item)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct ShortcutRowView: View {
    let item: ShortcutItemData

    var body: some View {
        LabeledContent {
            ShortcutKeyCaps(keys: item.keys)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                if let context = item.context {
                    Text(context)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ShortcutKeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(TypographyTokens.caption2.weight(.medium))
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, SpacingTokens.xxs2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.quaternary)
                    )
            }
        }
    }
}

private struct ShortcutSectionData: Identifiable {
    let title: String
    let items: [ShortcutItemData]

    var id: String { title }

    static let defaults: [ShortcutSectionData] = [
        ShortcutSectionData(
            title: "Workspace",
            items: [
                .init(title: "New Query Tab", context: "Open a new SQL editing tab.", keys: ["⌘", "T"]),
                .init(title: "Next Tab", context: "Switch to the next workspace tab.", keys: ["⌃", "⇥"]),
                .init(title: "Previous Tab", context: "Switch to the previous workspace tab.", keys: ["⌃", "⇧", "⇥"]),
                .init(title: "Show Tab Overview", context: "Toggle the tab overview switcher.", keys: ["⌘", "O"]),
                .init(title: "Close Query Tab", context: "Close the active tab.", keys: ["⌘", "W"]),
                .init(title: "Reopen Closed Tab", context: "Restore the most recently closed tab.", keys: ["⌘", "⇧", "T"])
            ]
        ),
        ShortcutSectionData(
            title: "Query Editing",
            items: [
                .init(title: "Run Selected Query", context: "Execute the highlighted SQL in the query editor.", keys: ["⌘", "Return"]),
                .init(title: "Format Query", context: "Format the current SQL using the configured style.", keys: ["⌘", "⇧", "F"]),
                .init(title: "Show EchoSense Suggestions", context: "Reopen the EchoSense popover after dismissal.", keys: ["⌘", "."]),
                .init(title: "Manual EchoSense Trigger", context: "Force suggestions even when auto-popup is suppressed.", keys: ["Ctrl", "Space"])
            ]
        ),
        ShortcutSectionData(
            title: "Results Grid",
            items: [
                .init(title: "Copy Selection", context: "Copy the selected cells.", keys: ["⌘", "C"]),
                .init(title: "Copy with Headers", context: "Include column headers with the copied cells.", keys: ["⌘", "⇧", "C"])
            ]
        ),
        ShortcutSectionData(
            title: "Connections",
            items: [
                .init(title: "Open Manage Connections", context: "Open the Manage Connections window.", keys: ["⌘", "⇧", "M"])
            ]
        )
    ]
}

private struct ShortcutItemData: Identifiable {
    let title: String
    let context: String?
    let keys: [String]

    var id: String { title }
}
