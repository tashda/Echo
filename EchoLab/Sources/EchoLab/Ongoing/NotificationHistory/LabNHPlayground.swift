import SwiftUI

/// Round 17 · Notification history. Echo today beside three ways to show the history in the
/// inspector's column and open a notification to its whole message. Click rows to open them.
struct LabNHPlayground: View {
    @State private var grouping: LabNHGrouping = .time
    @State private var motion: LabNHExpandMotion = .grow
    @State private var speed: LabSpeed = .standard
    @State private var openA: String? = "q1"
    @State private var openB: String? = "q1"
    @State private var openC: String? = "q1"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LabStage(title: "Notification history · round 17") {
            Picker("Group", selection: $grouping) { ForEach(LabNHGrouping.allCases) { Text($0.rawValue).tag($0) } }
                .fixedSize()
            Picker("Opening", selection: $motion) { ForEach(LabNHExpandMotion.allCases) { Text($0.rawValue).tag($0) } }
                .fixedSize()
            Picker("Speed", selection: $speed) { ForEach(LabSpeed.allCases) { Text($0.rawValue).tag($0) } }
                .fixedSize()
        } content: {
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: SpacingTokens.lg) {
                    column("Echo today", summary: "A grouped box per server; the title and message run together and are cut at two lines.") {
                        LabNHTodayColumn(notices: LabNHNotice.samples)
                    }
                    column(LabNHStyle.timeline.rawValue, summary: LabNHStyle.timeline.summary) {
                        LabNHTimeline(notices: LabNHNotice.samples, grouping: grouping, motion: motion, openID: $openA)
                    }
                    column(LabNHStyle.cards.rawValue, summary: LabNHStyle.cards.summary) {
                        LabNHCards(notices: LabNHNotice.samples, grouping: grouping, motion: motion, openID: $openB)
                    }
                    column(LabNHStyle.listDetail.rawValue, summary: LabNHStyle.listDetail.summary, scrolls: false) {
                        LabNHListDetail(notices: LabNHNotice.samples, openID: $openC)
                    }
                    LabNHQuestions()
                }
                .padding(SpacingTokens.md)
                .animation(speed.spring(reduceMotion: reduceMotion), value: openA)
                .animation(speed.spring(reduceMotion: reduceMotion), value: openB)
                .animation(speed.spring(reduceMotion: reduceMotion), value: openC)
                .animation(speed.spring(reduceMotion: reduceMotion), value: grouping)
            }
        }
    }

    /// A column as Echo draws it: one workspace card on the canvas.
    private func column<Content: View>(_ title: String, summary: String, scrolls: Bool = true, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.headline)
            Text(summary)
                .font(TypographyTokens.callout)
                .foregroundStyle(ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if scrolls {
                    ScrollView { content().padding(LayoutTokens.Inspector.cardPadding) }
                        .scrollIndicators(.never)
                } else {
                    content().padding(LayoutTokens.Inspector.cardPadding)
                }
            }
            .frame(width: LabNHMetrics.columnWidth, height: LabNHMetrics.columnHeight, alignment: .top)
            .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
                .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
            .shadow(ShadowTokens.workspaceCard)
            .padding(SpacingTokens.sm)
            .background(ColorTokens.Workspace.canvas, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        }
        .frame(width: LabNHMetrics.columnWidth + SpacingTokens.lg, alignment: .leading)
    }
}

private struct LabNHQuestions: View {
    private let questions: [(String, String)] = [
        ("1 · Which history?", "Open the long Postgres error and the failed backup in A, B and C. Which reads and copies best, and which fits Echo?"),
        ("2 · Group", "Group › By time or By server. Days read like a log; servers match the tree."),
        ("3 · Opening", "Opening › Grow or Fade in, at both speeds. Does the row grow smoothly, or should the message just appear?"),
        ("4 · Unread", "New events are bold (A, C) or carry a blue dot (B); the header counts them. Enough, or too much?"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            Text("Questions").font(TypographyTokens.headline)
            ForEach(questions, id: \.0) { title, detail in
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(title).font(TypographyTokens.standard.weight(.semibold))
                    Text(detail)
                        .font(TypographyTokens.callout)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(width: SpacingTokens.xxxl * 4, alignment: .leading)
    }
}
