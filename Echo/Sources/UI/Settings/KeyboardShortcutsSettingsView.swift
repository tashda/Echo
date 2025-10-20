import SwiftUI
import Foundation

struct KeyboardShortcutsSettingsView: View {
    private let sections: [ShortcutSectionData] = [
        .init(
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
        .init(
            title: "Query Editing",
            items: [
                .init(title: "Run Selected Query", context: "Execute the highlighted SQL in the query editor.", keys: ["⌘", "Return"]),
                .init(title: "Format Query", context: "Format the current SQL using the configured style.", keys: ["⌘", "⇧", "F"]),
                .init(title: "Show EchoSense Suggestions", context: "Reopen the EchoSense popover after dismissal.", keys: ["⌘", "."]),
                .init(title: "Manual EchoSense Trigger", context: "Force suggestions even when auto-popup is suppressed.", keys: ["Ctrl", "Space"])
            ]
        ),
        .init(
            title: "Results Grid",
            items: [
                .init(title: "Copy Selection", context: "Copy the selected cells.", keys: ["⌘", "C"]),
                .init(title: "Copy with Headers", context: "Include column headers with the copied cells.", keys: ["⌘", "⇧", "C"])
            ]
        ),
        .init(
            title: "Connections",
            items: [
                .init(title: "Open Manage Connections", context: "Open the Manage Connections window.", keys: ["⌘", "⇧", "M"])
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Use keyboard shortcuts to stay in flow while working in Echo. These shortcuts are available wherever the related feature is active.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(section.items) { item in
                                ShortcutRowView(item: item)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
    }
}

private struct ShortcutRowView: View {
    let item: ShortcutItemData

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                if let context = item.context {
                    Text(context)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            ShortcutKeyCaps(keys: item.keys)
        }
        .padding(.vertical, 6)
    }
}

private struct ShortcutKeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
            }
        }
    }
}

private struct ShortcutSectionData: Identifiable {
    let id = UUID()
    let title: String
    let items: [ShortcutItemData]
}

private struct ShortcutItemData: Identifiable {
    let id = UUID()
    let title: String
    let context: String?
    let keys: [String]
}
