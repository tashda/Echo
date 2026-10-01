import SwiftUI

/// The notification history in the inspector's column (plan N3; round 17: D · Compact cards,
/// by time, fading in, H3 header, A2 actions). One card: the title with a quiet count of what's
/// new, one ⋯ menu for filters and Clear, then the day's events as compact cards. A card opens to
/// the whole message, selectable, with small buttons for its link and Copy.
struct NotificationHistoryPanel: View {
    let history: NotificationHistory

    @State private var filter: NotificationHistoryFilter = .all
    @State private var openRecordID: UUID?
    @Environment(\.echoMotion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            header
                .padding([.horizontal, .top], LayoutTokens.Inspector.cardPadding)
            ScrollView {
                list
                    .padding([.horizontal, .bottom], LayoutTokens.Inspector.cardPadding)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
        .animation(motion.standard, value: openRecordID)
        .animation(motion.standard, value: filter)
    }

    /// H3: the count sits quietly beside the title; filters and Clear share one ⋯ menu.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
            Text(filter == .all ? "Notifications" : "\(filter.rawValue) Notifications")
                .font(TypographyTokens.headline)
            if !history.newRecordIDs.isEmpty {
                Text("\(history.newRecordIDs.count)")
                    .font(TypographyTokens.headline.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .accessibilityLabel("\(history.newRecordIDs.count) new")
            }
            Spacer(minLength: SpacingTokens.none)
            Menu {
                Picker("Show", selection: $filter) {
                    ForEach(NotificationHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
                Divider()
                Button("Clear All", role: .destructive) { history.clear() }
                    .disabled(history.records.isEmpty)
            } label: {
                Label("Filter and Clear", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
            .fixedSize()
            .help("Filter and Clear")
        }
    }

    @ViewBuilder
    private var list: some View {
        let groups = history.groupedByDay(filter)
        if groups.isEmpty {
            Text(filter == .all ? "No notifications" : "No \(filter.rawValue.lowercased()) notifications")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.top, SpacingTokens.xs)
        } else {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                ForEach(groups, id: \.title) { group in
                    Text(group.title)
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.xxs)
                        .padding(.top, SpacingTokens.xs)
                    ForEach(group.records) { record in
                        NotificationHistoryCard(
                            record: record,
                            isNew: history.newRecordIDs.contains(record.id),
                            isOpen: openRecordID == record.id
                        ) {
                            openRecordID = openRecordID == record.id ? nil : record.id
                        }
                    }
                }
            }
        }
    }
}
