import SwiftUI

/// Round 15 · notifications and where the history opens, as a `RoundSpec`: one live window.
@MainActor
enum NotificationsRound {
    static let center = LabNoticeCenter()

    static let spec = RoundSpec(
        controls: [
            .of("history", "Where the history opens", LabNoticeCenterStyle.self, default: .drawer,
                question: "Switch History, open the bell, open a long error, copy it. Where should the history open?",
                recommend: .drawer,
                why: "B: the history takes the inspector's column, with room for long messages and the same card and boxes as the inspector.",
                summary: \.summary),
            .of("top", "Toasts' top edge", LabToastTop.self, default: .belowTabBar,
                question: "Post a few with each setting, with and without the inspector. Where do toasts start?",
                recommend: .belowTabBar,
                why: "Inside the tab's first card, below the tab bar, so they never cover the toolbar and line up with the card."),
            RoundSpec.Control(id: "inspector", title: "Inspector", question: nil,
                              choices: [.init(id: "off", name: "Hidden"), .init(id: "on", name: "Shown")], defaultChoice: "off"),
            .of("speed", "Speed", LabSpeed.self, default: .standard),
        ],
        actions: [
            .init(id: "post", title: "Post a notification", symbol: "bell.badge") { _ in center.post() },
            .init(id: "repeat", title: "Post the same again", symbol: "arrow.triangle.2.circlepath") { _ in center.repeatLatest() },
        ],
        exhibits: [
            .init(id: "window", title: "Live window", summary: "Post a few, hover them, open the bell, show the inspector.",
                  isWide: true, designWidth: LabRound15NoticeMetrics.windowWidth + SpacingTokens.lg,
                  designHeight: LabRound15NoticeMetrics.windowHeight + SpacingTokens.lg) { values in
                NotificationsExhibit(values: values)
            },
        ]
    )
}

private struct NotificationsExhibit: View {
    let values: RoundValues
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var center: LabNoticeCenter { NotificationsRound.center }

    var body: some View {
        let speed = LabSpeed(rawValue: values["speed"]) ?? .standard
        let showsInspector = values["inspector"] == "on"
        LabNoticeWindow(center: center,
                        style: LabNoticeCenterStyle(rawValue: values["history"]) ?? .drawer,
                        top: LabToastTop(rawValue: values["top"]) ?? .belowTabBar,
                        showsInspector: showsInspector)
            .padding(SpacingTokens.xs)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.toasts)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.hoveredToast)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.isOpen)
            .animation(speed.spring(reduceMotion: reduceMotion), value: center.expandedItem)
            .animation(speed.spring(reduceMotion: reduceMotion), value: showsInspector)
    }
}
