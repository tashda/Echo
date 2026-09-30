import SwiftUI

/// The history in the inspector's column, copied from NotificationHistoryPanel and
/// NotificationHistoryCard (round 17: compact cards by day, fading in, count by the title with one
/// ⋯ menu, small buttons).
struct NotificationsSpecimenHistory: View {
    let state: NotificationsSpecimenState
    @State private var openID: UUID?
    @Environment(\.echoMotion) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            header
                .specAnchor("3.3")
                .padding([.horizontal, .top], LayoutTokens.Inspector.cardPadding)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    ForEach(days, id: \.0) { title, events in
                        Text(title)
                            .font(TypographyTokens.detail.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.horizontal, SpacingTokens.xxs)
                            .padding(.top, SpacingTokens.xs)
                            .specAnchor("3.2")
                        ForEach(events) { card($0) }
                    }
                }
                .padding([.horizontal, .bottom], LayoutTokens.Inspector.cardPadding)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
        .animation(motion.standard, value: openID)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
            Text("Notifications").font(TypographyTokens.headline)
            if !state.newIDs.isEmpty {
                Text("\(state.newIDs.count)")
                    .font(TypographyTokens.headline.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer(minLength: SpacingTokens.none)
            Menu {
                Button("All") {}
                Button("Errors") {}
                Button("Connection") {}
                Button("Queries") {}
                Button("Jobs") {}
                Divider()
                Button("Clear All", role: .destructive) { state.history.removeAll() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .specAnchor("3.4")
            .help("Filter and Clear")
        }
    }

    /// Today, Yesterday, then the date.
    private var days: [(String, [NotificationsSpecimenState.Event])] {
        var groups: [(String, [NotificationsSpecimenState.Event])] = []
        for event in state.history {
            let title = Calendar.current.isDateInToday(event.date) ? "Today"
                : Calendar.current.isDateInYesterday(event.date) ? "Yesterday"
                : event.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
            if groups.last?.0 == title { groups[groups.count - 1].1.append(event) } else { groups.append((title, [event])) }
        }
        return groups
    }

    private func card(_ event: NotificationsSpecimenState.Event) -> some View {
        let isOpen = openID == event.id
        let parts = event.message.components(separatedBy: ": ")
        let headline = parts.first ?? event.message
        let detail = parts.count > 1 ? parts.dropFirst().joined(separator: ": ") : nil
        return VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: event.icon).foregroundStyle(event.tint)
                Text(headline)
                    .font(TypographyTokens.standard.weight(state.newIDs.contains(event.id) ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: SpacingTokens.xs)
                Text(event.date, format: .relative(presentation: .named))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            if isOpen {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(event.server).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    if let detail {
                        Text(detail)
                            .font(TypographyTokens.detail.monospaced())
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: SpacingTokens.xs) {
                        if let link = event.link { Button(link) {} }
                        Button("Copy") {}
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.leading, SpacingTokens.lg)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous))
        .specAnchor(isOpen ? "3.6" : "3.5")
        .contentShape(Rectangle())
        .onTapGesture { openID = isOpen ? nil : event.id }
    }
}

/// The column's other mode: the details, drawn as the inspector's grouped boxes.
struct NotificationsSpecimenDetails: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Label("Row 3", systemImage: "tablecells")
                .font(TypographyTokens.standard.weight(.semibold))
                .padding(.horizontal, SpacingTokens.xxs)
            VStack(spacing: SpacingTokens.none) {
                ForEach([("emp_no", "10003"), ("first_name", "Parto"), ("last_name", "Bamford")], id: \.0) { label, value in
                    HStack {
                        Text(label).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                        Spacer()
                        Text(value).font(TypographyTokens.standard)
                    }
                    .padding(.vertical, SpacingTokens.xxs)
                }
            }
            .padding(.horizontal, LayoutTokens.Inspector.cardPadding)
            .background(ColorTokens.Workspace.groupFill, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous))
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(LayoutTokens.Inspector.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }
}
