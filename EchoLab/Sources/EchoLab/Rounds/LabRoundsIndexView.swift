import SwiftUI

/// Every round, newest first, laid out like a mailbox: the rounds on the left grouped by day,
/// the selected round in a reading pane with what it asked, what came of it and its pages.
struct LabRoundsIndexView: View {
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator
    @AppStorage("lab.rounds.selected") private var selectedID: String?
    @State private var search = ""

    private var rounds: [LabRounds.Info] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return LabRounds.all.filter { round in
            query.isEmpty || round.title.lowercased().contains(query) || round.label.lowercased().contains(query) || LabRoundName.split(round.label).tag?.contains(query) == true
                || round.asked.lowercased().contains(query) || round.outcome.lowercased().contains(query)
        }
    }

    /// The status that most needs attention across a round's pages.
    private func status(of round: LabRounds.Info) -> LabStatus {
        let all = round.pageIDs.compactMap { LabRegistry.page(id: $0) }.compactMap { store.status(of: $0) }
        for status in [LabStatus.newFeedback, .judging, .accepted, .inEcho] where all.contains(status) { return status }
        return .decided
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                LabMailHeader(title: "Rounds", subtitle: "\(LabRounds.all.count) in all", search: $search) { EmptyView() }
                Divider()
                list
            }
            .frame(width: 400)
            Divider()
            reading
        }
        .background(ColorTokens.Workspace.canvas)
    }

    private var list: some View {
        let days = rounds.reduce(into: [String]()) { if !$0.contains($1.date) { $0.append($1.date) } }
        return List(selection: $selectedID) {
            ForEach(days, id: \.self) { day in
                Section(day) {
                    ForEach(rounds.filter { $0.date == day }) { round in row(round).tag(round.id) }
                }
            }
        }
        .listStyle(.inset)
        .onAppear { if selectedID == nil || !rounds.contains(where: { $0.id == selectedID }) { selectedID = rounds.first?.id } }
    }

    private func row(_ round: LabRounds.Info) -> some View {
        let status = status(of: round)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.symbol).foregroundStyle(status.tint).frame(width: 16).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(round.title).font(TypographyTokens.standard.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    LabRoundLabel(round: round)
                }
                Text(round.asked).font(TypographyTokens.detail).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Reading pane

    @ViewBuilder
    private var reading: some View {
        if let id = selectedID, let round = LabRounds.all.first(where: { $0.id == id }) {
            RoundReadingPane(round: round, status: status(of: round))
        } else {
            LabMailEmpty(title: "Select a round", symbol: "clock.arrow.circlepath")
        }
    }
}

private struct RoundReadingPane: View {
    let round: LabRounds.Info
    let status: LabStatus
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    HStack(spacing: 6) { LabRoundLabel(round: round); Text(round.date) }
                        .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    Text(round.title).font(.system(size: 26, weight: .bold))
                    HStack(spacing: 6) {
                        LabStatusChip(status: status)
                        LabTag(text: "\(round.pageIDs.count) page\(round.pageIDs.count == 1 ? "" : "s")", symbol: "doc.on.doc")
                    }
                }
                LabReadingCard(title: "What it asked", symbol: "questionmark.bubble") {
                    Text(round.asked).font(TypographyTokens.prominent).fixedSize(horizontal: false, vertical: true)
                }
                LabReadingCard(title: "What came of it", symbol: "checkmark.bubble") {
                    Text(round.outcome).font(TypographyTokens.prominent).fixedSize(horizontal: false, vertical: true)
                }
                if !round.topics.isEmpty {
                    LabReadingCard(title: "Topics", symbol: "list.bullet") {
                        ForEach(Array(round.topics.enumerated()), id: \.offset) { index, topic in
                            if index > 0 { Divider() }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title).font(TypographyTokens.standard.weight(.semibold))
                                Text(topic.outcome).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                LabReadingCard(title: "Pages", symbol: "doc.on.doc") {
                    ForEach(Array(round.pageIDs.enumerated()), id: \.offset) { index, id in
                        if let page = LabRegistry.page(id: id) {
                            if index > 0 { Divider() }
                            Button { navigator.openPage(id) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        LabRoundTitle(text: page.title, pageID: page.id, font: TypographyTokens.standard.weight(.medium))
                                        Text(LabAreas.area(id: LabAreas.areaID(ofPage: id))?.title ?? "")
                                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                                    }
                                    Spacer()
                                    if let s = store.status(of: page) { LabStatusChip(status: s) }
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(ColorTokens.Text.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(SpacingTokens.lg)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
