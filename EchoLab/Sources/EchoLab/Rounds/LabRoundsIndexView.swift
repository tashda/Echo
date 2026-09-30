import SwiftUI

/// Every round in one place, newest first, with what it asked and what came of it.
struct LabRoundsIndexView: View {
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                Text("Every design round, newest first. Open a page to try the options or read the decision.")
                    .font(TypographyTokens.prominent).foregroundStyle(ColorTokens.Text.secondary)
                ForEach(LabRounds.all) { round in
                    RoundIndexCard(round: round) { navigator.openPage($0) }
                }
            }
            .padding(SpacingTokens.lg)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct RoundIndexCard: View {
    let round: LabRounds.Info
    let open: (String) -> Void
    @Environment(LabStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(round.label) · \(round.date)")
                    .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                Text(round.title).font(TypographyTokens.title3.weight(.semibold))
            }
            labelled("What it asked", round.asked)
            labelled("What came of it", round.outcome)
            if !round.topics.isEmpty {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text("Topics").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.tertiary)
                    ForEach(round.topics, id: \.title) { topic in
                        (Text(topic.title + ": ").font(TypographyTokens.standard.weight(.medium))
                            + Text(topic.outcome).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary))
                    }
                }
            }
            HStack(spacing: SpacingTokens.xs) {
                ForEach(round.pageIDs, id: \.self) { id in
                    if let page = LabRegistry.page(id: id) {
                        Button {
                            open(id)
                        } label: {
                            HStack(spacing: 4) {
                                Text(page.title.replacingOccurrences(of: "\(round.label) · ", with: ""))
                                if let status = store.status(of: page) {
                                    Text(status.rawValue).foregroundStyle(ColorTokens.Text.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.Surface.rest, in: .rect(cornerRadius: 14, style: .continuous))
    }

    private func labelled(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.tertiary)
            Text(text).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
        }
    }
}
