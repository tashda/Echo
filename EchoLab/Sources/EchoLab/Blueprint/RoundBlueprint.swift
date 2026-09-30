import SwiftUI

/// The blueprint every round page follows. A round asks one or more **topics**; each topic is a
/// question with its **options** drawn live side by side, so you can try them and pick one.
///
///     Header        which round, when, what it asks
///     Test bar      appearance, card corners, motion speed, Reduce Motion, Replay
///     Topics        numbered; each has the question, how to try it, the options, your pick
///     Your picks    a summary you can accept or send back as feedback
///
/// Nothing on a round page needs a horizontal scroll: specimens scale down to fit their card.
@MainActor
struct RoundBlueprint {
    struct Option: Identifiable {
        let id: String
        let name: String
        /// One or two sentences: what makes this option different.
        let summary: String
        /// True for what Echo does today, so every option is judged against it.
        var isEchoToday = false
        /// The size the specimen was designed at; it is scaled down if the card is narrower.
        var designWidth: CGFloat
        var designHeight: CGFloat
        let specimen: () -> AnyView

        init<Specimen: View>(
            id: String, name: String, summary: String, isEchoToday: Bool = false,
            designWidth: CGFloat, designHeight: CGFloat,
            @ViewBuilder specimen: @escaping () -> Specimen
        ) {
            self.id = id
            self.name = name
            self.summary = summary
            self.isEchoToday = isEchoToday
            self.designWidth = designWidth
            self.designHeight = designHeight
            self.specimen = { AnyView(specimen()) }
        }
    }

    struct Topic: Identifiable {
        let id: String
        let title: String
        /// The decision, as a question.
        let question: String
        /// Exactly what to do and look at.
        let howToTry: String
        let options: [Option]
    }

    /// What this round asks, in a sentence or two.
    let intro: String
    let topics: [Topic]
}
