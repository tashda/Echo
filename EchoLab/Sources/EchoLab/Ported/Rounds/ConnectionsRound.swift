import SwiftUI

/// Round 14 · connections, as a `RoundSpec`: editing inside Manage Connections.
@MainActor
enum ConnectionsRound {
    static let spec = RoundSpec(
        exhibits: [
            .init(id: "manage", title: "Manage Connections", summary: "Select connections, change fields, press Save with the server empty, press +, press Test.",
                  isWide: true, designWidth: LayoutTokens.DesignLabRound14.manageWidth, designHeight: LayoutTokens.DesignLabRound14.manageHeight) { _ in
                LabRound14ManageConnections()
            },
        ],
        questions: [
            .init(id: "cn5", title: "Edit inside Manage Connections",
                  question: "Select connections, change fields, press Save with the server empty, press +, press Test. Does editing in the detail pane work?",
                  choices: [.init(id: "accept", name: "Accept"), .init(id: "refine", name: "Refine"), .init(id: "reject", name: "Reject")],
                  recommended: "accept",
                  why: "You chose CN5: one short sheet for Quick Connect and New Connection, with editing in Manage Connections' detail pane, so there is one form to learn."),
        ]
    )
}
