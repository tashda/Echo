import SwiftUI

/// Round 42.2 · Context menus: server. Echo today (connectionMenu, SQL Server): Refresh All, New
/// Query | Activity Monitor | Maintenance, Database Mail, Central Management Servers, Extended Events,
/// Availability Groups | Hide Offline Databases | Manage Connection, Disconnect | Properties.
@MainActor
enum ContextMenuServerRound {
    enum Tools: String, CaseIterable {
        case listed = "ST0 · The tools listed in the menu (today)"
        case submenu = "ST1 · The tools in an Open Tool submenu"
    }

    static let spec = RoundSpec(
        controls: [
            .of("tools", "Tools", Tools.self, default: .submenu,
                question: "Compare the server menus. Should the server's tools be in the menu or a submenu?",
                recommend: .submenu,
                why: "Five tools make the menu twice as long for things the dock's Management section already lists; a submenu keeps them one level away, which Apple allows (one level only)."),
        ],
        exhibits: LabCMExhibits.pair("server", row: ("server.rack", ColorTokens.Status.error, "dkloosql10-p"), today: LabCMMenus.serverToday) { values in
            LabCMMenus.serverProposal(toolsSubmenu: (Tools(rawValue: values["tools"]) ?? .submenu) == .submenu)
        },
        questions: [
            .init(id: "refresh", title: "Refresh All",
                  question: "Today it says Refresh All. What should it say?",
                  choices: [.init(id: "refresh", name: "SR0 · Refresh, as on every other object"), .init(id: "all", name: "SR1 · Refresh All")],
                  recommended: "refresh",
                  why: "On a server, Refresh refreshes the server: the same word in every menu is part of one order (42.1)."),
            .init(id: "connection", title: "Manage Connection",
                  question: "Manage Connection opens the connection's settings. Rename it?",
                  choices: [.init(id: "edit", name: "SC0 · Edit Connection"), .init(id: "keep", name: "SC1 · Keep Manage Connection")],
                  recommended: "edit",
                  why: "It edits this one connection; 'Manage Connections' is the window with all of them, and the near-identical names are confusing."),
        ]
    )
}
