import SwiftUI

/// Round 28.8 · Editor: zoom. New: Echo has no editor zoom today (only the schema diagram zooms);
/// the font size is a setting for every editor. The owner asked for a zoom control in the editor,
/// bottom left like SSMS or wherever it fits best. The proposal's control works: its steps and
/// its menu change the Zoom control on the left.
@MainActor
enum EditorZoomRound {
    static let spec = RoundSpec(
        controls: [
            .of("zoomPlace", "Where", LabQEZoomPlace.self, default: .bottomLeft,
                question: "Try each place in the Proposal and the gallery. Where should the zoom control live?",
                recommend: .bottomLeft,
                why: "Your idea, and where SSMS users look for it. The bottom-left corner sits over the gutter, which is narrow and has nothing to click near the bottom, while the right edge already has the scroll bar (or the outline edge) and toasts arrive top right. The footer chip is the connection's, not the editor's, and is hidden under the results; keys only can't be found.",
                summary: \.summary),
            .of("zoomLook", "Look", LabQEZoomLook.self, default: .menu,
                question: "Click the control in the Proposal in each look. Which should it be?",
                recommend: .menu,
                why: "One small pill with the percentage takes the least room over the code and opens a menu of sizes and Actual Size, like SSMS's box; − and + double its width for something ⌘+ and ⌘− already do. The magnifier adds a symbol nobody needs once the percentage is there."),
            .of("zoomShows", "When it shows", LabQEZoomShows.self, default: .always,
                question: "Set each, then set the zoom to 100% and back. When should the control be on screen?",
                recommend: .always,
                why: "You asked for a control you can see. At 100% it is a quiet grey pill; showing it only when zoomed means nobody finds it, and showing it on hover makes it flicker into view whenever the pointer crosses the editor."),
            .of("zoom", "Zoom", LabQEZoomLevel.self, default: .z100),
            LabQERound.sceneControl(default: .typing),
            LabQERound.baseControl,
        ],
        exhibits: [
            LabQERound.today("No zoom: the font size is a setting for every editor.", scene: .typing, before28: true),
            LabQERound.proposal("Built from the controls; the control works.", scene: .typing),
            LabQERound.gallery("Places", "Every place, on the proposal at the current zoom.", LabQEZoomPlace.self, \.zoomPlaceChoice, scene: .typing),
        ],
        questions: [
            .init(id: "scope", title: "What it zooms",
                  question: "You zoom to 150% in one tab. What else changes?",
                  choices: [
                      .init(id: "tab", name: "ZS0 · Only this tab, until it closes", summary: "Like SSMS: each query window has its own zoom."),
                      .init(id: "remembered", name: "ZS1 · Only this tab, remembered with it"),
                      .init(id: "all", name: "ZS2 · Every editor (it is the font size)"),
                  ],
                  recommended: "tab",
                  why: "Zoom is for a moment (showing a colleague, a long line); the font size setting is for every day. Remembering it per tab means a tab you reopen next week is mysteriously big."),
            .init(id: "keys", title: "Keys and gestures",
                  question: "Which ways in besides the control?",
                  choices: [
                      .init(id: "keysPinch", name: "ZK0 · ⌘+, ⌘− and ⌘0 in the View menu, and pinch"),
                      .init(id: "keysPinchScroll", name: "ZK1 · ZK0 and ⌘-scroll"),
                      .init(id: "keys", name: "ZK2 · The keys only"),
                  ],
                  recommended: "keysPinch",
                  why: "⌘+ ⌘− ⌘0 is what Safari, Xcode and SSMS use; pinch is how a trackpad zooms on the Mac. ⌘-scroll is a Windows habit that fires by accident with a Magic Mouse."),
            .init(id: "range", title: "Steps",
                  question: "Which sizes should it offer?",
                  choices: [
                      .init(id: "steps", name: "ZR0 · 50% to 200%: 50, 75, 90, 100, 110, 125, 150, 200"),
                      .init(id: "wide", name: "ZR1 · 25% to 400%, every 10%"),
                  ],
                  recommended: "steps",
                  why: "Below 50% code can't be read, and 200% of 13pt is already 26pt; the familiar browser steps make ⌘+ land on round numbers."),
            .init(id: "what", title: "Results too",
                  question: "Should the zoom also enlarge the results grid below?",
                  choices: [
                      .init(id: "editor", name: "ZW0 · The editor only, with its gutter and notes"),
                      .init(id: "both", name: "ZW1 · Editor and results together"),
                  ],
                  recommended: "editor",
                  why: "The control sits in the editor and SSMS zooms only the editor; the grid has its own size setting, and zooming both makes the results card jump while you read it."),
        ],
        exhibitTopic: ("Which zoom?", "Zoom the Proposal in and out with its own control. Is it worth adding to Echo?", "proposal",
                       "A small, always-there pill that zooms this editor (gutter and notes too) and resets with ⌘0."),
        presets: [
            .init(id: "recommended", name: "My recommendation", summary: "Bottom left, 100% with a menu, always shown.",
                  values: ["zoomPlace": LabQEZoomPlace.bottomLeft.rawValue, "zoomLook": LabQEZoomLook.menu.rawValue, "zoomShows": LabQEZoomShows.always.rawValue],
                  isRecommended: true),
            .init(id: "ssms", name: "Like SSMS", summary: "Bottom left, a percentage box, always there.",
                  values: ["zoomPlace": LabQEZoomPlace.bottomLeft.rawValue, "zoomLook": LabQEZoomLook.menu.rawValue, "zoomShows": LabQEZoomShows.always.rawValue,
                           "zoom": LabQEZoomLevel.z125.rawValue]),
            .init(id: "quiet", name: "Quiet", summary: "Bottom right, − 100% +, only when zoomed.",
                  values: ["zoomPlace": LabQEZoomPlace.bottomRight.rawValue, "zoomLook": LabQEZoomLook.stepper.rawValue, "zoomShows": LabQEZoomShows.notDefault.rawValue]),
            .init(id: "keys", name: "Keys only",
                  values: ["zoomPlace": LabQEZoomPlace.keysOnly.rawValue]),
        ]
    )
}

extension LabQEStyle {
    /// The gallery's handle on the zoom place (the style keeps it optional, for Echo today).
    var zoomPlaceChoice: LabQEZoomPlace {
        get { zoomPlace ?? .bottomLeft }
        set { zoomPlace = newValue }
    }
}
