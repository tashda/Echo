import SwiftUI

/// A small "New" marker for anything added after the owner's last review.
struct LabNewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 9, weight: .bold)).tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 5).frame(height: 15)
            .background(ColorTokens.accent, in: Capsule())
    }
}

/// At the top of the decision panel: what changed since the owner last reviewed the round. It
/// lists the agent's revision notes, and, automatically, every question and option marked
/// `addedIn:` a revision the owner hasn't seen.
struct RoundWhatsNew: View {
    let page: LabPage
    let decision: RoundDecision
    @Environment(LabStore.self) private var store

    private var newTopics: [RoundDecision.Topic] { decision.topics.filter { store.isNew(page, addedIn: $0.addedIn) } }
    private var newChoices: [(topic: RoundDecision.Topic, choice: RoundDecision.Choice)] {
        decision.topics.filter { !store.isNew(page, addedIn: $0.addedIn) }.flatMap { topic in
            topic.choices.filter { store.isNew(page, addedIn: $0.addedIn) }.map { (topic, $0) }
        }
    }

    var body: some View {
        let revisions = store.revisionsSinceReview(of: page)
        if !revisions.isEmpty || !newTopics.isEmpty || !newChoices.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack {
                    Label("New since your last review", systemImage: "sparkles").font(TypographyTokens.headline)
                    Spacer()
                    Text("rev \(store.reviewedRevision(of: page)) → \(store.revision(of: page))")
                        .font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
                }
                ForEach(revisions) { revision in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Revision \(revision.number) · \(revision.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.accent)
                        if !revision.summary.isEmpty {
                            Text(revision.summary).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(revision.changes, id: \.self) { change in
                            Label { Text(change).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "plus.circle.fill").foregroundStyle(ColorTokens.accent) }
                                .font(TypographyTokens.standard)
                        }
                    }
                }
                if !newTopics.isEmpty || !newChoices.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(newTopics) { topic in
                            Label { Text("New question: \(topic.title)") } icon: { LabNewBadge() }.font(TypographyTokens.standard)
                        }
                        ForEach(Array(newChoices.enumerated()), id: \.offset) { _, item in
                            Label { Text("\(item.choice.name)  in \(item.topic.title)").fixedSize(horizontal: false, vertical: true) } icon: { LabNewBadge() }
                                .font(TypographyTokens.standard)
                        }
                    }
                }
                Button { store.markReviewed(page) } label: { Label("Mark as seen", systemImage: "checkmark") }
                    .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
            }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.accent.opacity(0.10), in: .rect(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ColorTokens.accent.opacity(0.35), lineWidth: 1))
        }
    }
}
