import SwiftUI

/// Round 17, written as a `RoundSpec`: Echo today and three proposals as exhibits; the history's
/// grouping and opening motion as controls.
@MainActor
enum LabNHRound {
    private static let width = LabNHMetrics.columnWidth + SpacingTokens.sm * 2
    private static let height = LabNHMetrics.columnHeight + SpacingTokens.sm * 2

    static let spec = RoundSpec(
        controls: [
            .of("grouping", "Group", LabNHGrouping.self, default: .time,
                question: "Group › By time or By server. Days read like a log; servers match the tree.",
                recommend: .time,
                why: "Notifications are looked at in the order they happened, and every row still names its server."),
            .of("motion", "Opening", LabNHExpandMotion.self, default: .grow,
                question: "Opening › Grow or Fade in, at both speeds. Does the row grow smoothly, or should the message just appear?",
                recommend: .grow,
                why: "Motion should explain change: growing shows the message coming out of its row."),
            .of("header", "Header", LabNHHeaderStyle.self, default: .titleMenu,
                question: "Header › try each. How should the unread count and Clear look at the top of the history?",
                recommend: .titleMenu,
                why: "One quiet number beside the title and one ⋯ menu for filters and Clear leaves the header calm; Clear is rare and destructive, so it doesn't need a permanent button.",
                summary: { $0.summary }),
            .of("actions", "Actions", LabNHActionStyle.self, default: .smallButtons,
                question: "Open the long Postgres error, then try each Actions style. How should Open Tab and Copy look?",
                recommend: .smallButtons,
                why: "Small native bordered buttons read as real buttons without shouting, match Mail and Finder, and stay legible in light, dark and Increase Contrast. Glass belongs on floating controls, not inside an opaque card.",
                summary: { $0.summary }),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "A grouped box per server; the title and message run together and are cut at two lines.",
                  isEchoToday: true, designWidth: width, designHeight: height) { _ in
                LabNHChrome { LabNHTodayColumn(notices: LabNHNotice.samples) }
            },
            .init(id: "timeline", title: LabNHStyle.timeline.rawValue, summary: LabNHStyle.timeline.summary,
                  designWidth: width, designHeight: height) { values in LabNHTimelineExhibit(values: values) },
            .init(id: "cards", title: LabNHStyle.cards.rawValue, summary: LabNHStyle.cards.summary,
                  designWidth: width, designHeight: height) { values in LabNHCardsExhibit(values: values) },
            .init(id: "listDetail", title: LabNHStyle.listDetail.rawValue, summary: LabNHStyle.listDetail.summary,
                  designWidth: width, designHeight: height) { values in LabNHListDetailExhibit().labNHStyles(values) },
            .init(id: "compactCards", title: LabNHStyle.compactCards.rawValue, summary: LabNHStyle.compactCards.summary,
                  designWidth: width, designHeight: height) { values in LabNHMoreExhibit(values: values, style: .compactCards) },
            .init(id: "attentionFirst", title: LabNHStyle.attentionFirst.rawValue, summary: LabNHStyle.attentionFirst.summary,
                  designWidth: width, designHeight: height) { values in LabNHMoreExhibit(values: values, style: .attentionFirst) },
            .init(id: "stacked", title: LabNHStyle.stacked.rawValue, summary: LabNHStyle.stacked.summary,
                  designWidth: width, designHeight: height) { values in LabNHMoreExhibit(values: values, style: .stacked) },
        ],
        questions: [
            .init(id: "unread", title: "Unread",
                  question: "New events are bold (A, C) or carry a blue dot (B); the header counts them. Enough, or too much?",
                  choices: [.init(id: "enough", name: "Enough"), .init(id: "tooMuch", name: "Too much"), .init(id: "notEnough", name: "Not enough")],
                  recommended: "enough",
                  why: "Bold plus the count in the header already says what is new; a dot adds a second signal for the same thing."),
        ],
        exhibitTopic: ("Which history?", "Open the long Postgres error and the failed backup in each. Which reads and copies best, and which fits Echo?",
                       "compactCards",
                       "You picked cards; compact cards keep that look but show one line per event, so more fit and nothing is said twice. The message and actions only appear when a card is opened. Attention first adds a second list style, and stacks hide events behind a click."),
        presets: [
            .init(id: "log", name: "Log: by time, grow", summary: "My recommendation.",
                  values: ["grouping": LabNHGrouping.time.rawValue, "motion": LabNHExpandMotion.grow.rawValue,
                           "header": LabNHHeaderStyle.titleMenu.rawValue, "actions": LabNHActionStyle.smallButtons.rawValue],
                  isRecommended: true),
            .init(id: "servers", name: "By server, fade in", values: ["grouping": LabNHGrouping.server.rawValue, "motion": LabNHExpandMotion.fade.rawValue]),
        ]
    )
}

/// One column as Echo draws it: a workspace card on the canvas.
struct LabNHChrome<Content: View>: View {
    var scrolls = true
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if scrolls { ScrollView { content.padding(LayoutTokens.Inspector.cardPadding) }.scrollIndicators(.never) }
            else { content.padding(LayoutTokens.Inspector.cardPadding) }
        }
        .frame(width: LabNHMetrics.columnWidth, height: LabNHMetrics.columnHeight, alignment: .top)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: LayoutTokens.Workspace.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: LayoutTokens.Workspace.cardCornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
        .shadow(ShadowTokens.workspaceCard)
        .padding(SpacingTokens.sm)
    }
}

private struct LabNHTimelineExhibit: View {
    let values: RoundValues
    @State private var openID: String? = "q1"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let speed = LabSpeed(rawValue: values["speed"]) ?? .standard
        LabNHChrome {
            LabNHTimeline(notices: LabNHNotice.samples, grouping: LabNHGrouping(rawValue: values["grouping"]) ?? .time,
                          motion: LabNHExpandMotion(rawValue: values["motion"]) ?? .grow, openID: $openID)
        }
        .labNHStyles(values)
        .animation(speed.spring(reduceMotion: reduceMotion), value: openID)
    }
}

private struct LabNHCardsExhibit: View {
    let values: RoundValues
    @State private var openID: String? = "q1"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let speed = LabSpeed(rawValue: values["speed"]) ?? .standard
        LabNHChrome {
            LabNHCards(notices: LabNHNotice.samples, grouping: LabNHGrouping(rawValue: values["grouping"]) ?? .time,
                       motion: LabNHExpandMotion(rawValue: values["motion"]) ?? .grow, openID: $openID)
        }
        .labNHStyles(values)
        .animation(speed.spring(reduceMotion: reduceMotion), value: openID)
    }
}

private struct LabNHListDetailExhibit: View {
    @State private var openID: String? = "q1"

    var body: some View {
        LabNHChrome(scrolls: false) { LabNHListDetail(notices: LabNHNotice.samples, openID: $openID) }
    }
}

/// D, E and F, which share one exhibit shell.
private struct LabNHMoreExhibit: View {
    let values: RoundValues
    let style: LabNHStyle
    @State private var openID: String? = "q1"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let speed = LabSpeed(rawValue: values["speed"]) ?? .standard
        let motion = LabNHExpandMotion(rawValue: values["motion"]) ?? .grow
        LabNHChrome {
            switch style {
            case .attentionFirst:
                LabNHAttentionFirst(notices: LabNHNotice.samples, motion: motion, openID: $openID)
            case .stacked:
                LabNHStacked(notices: LabNHNotice.samples, motion: motion, openID: $openID)
            default:
                LabNHCompactCards(notices: LabNHNotice.samples, grouping: LabNHGrouping(rawValue: values["grouping"]) ?? .time,
                                  motion: motion, openID: $openID)
            }
        }
        .labNHStyles(values)
        .animation(speed.spring(reduceMotion: reduceMotion), value: openID)
    }
}

extension View {
    /// Applies the round's header and action styles to a proposal.
    func labNHStyles(_ values: RoundValues) -> some View {
        environment(\.labNHHeaderStyle, LabNHHeaderStyle(rawValue: values["header"]) ?? .titleMenu)
            .environment(\.labNHActionStyle, LabNHActionStyle(rawValue: values["actions"]) ?? .smallButtons)
    }
}
