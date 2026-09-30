import SwiftUI

/// The history in the inspector's column, copied from NotificationHistoryPanel (commit 755f8254):
/// one card, a grouped box per server, rows that open in place to the whole message.
struct NotificationsSpecimenHistory: View {
    let state: NotificationsSpecimenState
    @State private var openID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                Text("Notifications").font(TypographyTokens.headline)
                Spacer(minLength: SpacingTokens.none)
                Menu {
                    Button("All") {}
                    Button("Errors") {}
                    Button("Connection") {}
                    Button("Queries") {}
                    Button("Jobs") {}
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                Button("Clear") { state.history.removeAll() }
                    .buttonStyle(.borderless)
            }
            .padding([.horizontal, .top], LayoutTokens.Inspector.cardPadding)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.md) {
                    ForEach(servers, id: \.self) { server in
                        group(server)
                    }
                }
                .padding([.horizontal, .bottom], LayoutTokens.Inspector.cardPadding)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }

    private var servers: [String] {
        state.history.map(\.server).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }

    private func group(_ server: String) -> some View {
        let records = state.history.filter { $0.server == server }
        return VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(server)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.xxs)
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    row(record, isLast: index == records.count - 1)
                }
            }
            .padding(.horizontal, LayoutTokens.Inspector.cardPadding)
            .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous))
        }
    }

    private func row(_ record: NotificationsSpecimenState.Event, isLast: Bool) -> some View {
        let isOpen = openID == record.id
        return VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Image(systemName: record.icon).font(TypographyTokens.detail).foregroundStyle(record.tint)
                Text(record.message)
                    .font(TypographyTokens.standard)
                    .lineLimit(isOpen ? nil : 2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: isOpen)
                Spacer(minLength: SpacingTokens.xs)
                Text(record.date, format: .relative(presentation: .named))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            if isOpen {
                HStack(spacing: SpacingTokens.sm) {
                    if let link = record.link { Button(link) {} }
                    Button("Copy") {}
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(ColorTokens.accent)
                .padding(.leading, SpacingTokens.lg)
            }
        }
        .padding(.vertical, SpacingTokens.xs)
        .contentShape(Rectangle())
        .onTapGesture { openID = isOpen ? nil : record.id }
        .overlay(alignment: .bottom) { if !isLast { Divider() } }
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
            .background(ColorTokens.Background.secondary, in: .rect(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous))
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(LayoutTokens.Inspector.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }
}
