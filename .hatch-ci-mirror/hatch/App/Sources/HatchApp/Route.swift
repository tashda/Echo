import Foundation

/// Where the user is in the app. The sidebar sets it (decision B1); a ticket opens full width (decision C1).
enum Route: Hashable {
    case desk, tickets, board, previews, specs, decisions, agents, log, projects
    case ticket(Int)
    case newTicket

    var title: String {
        switch self {
        case .desk: "Desk"
        case .tickets: "Tickets"
        case .board: "Board"
        case .previews: "Previews"
        case .specs: "Specs"
        case .decisions: "Decisions"
        case .agents: "Agents"
        case .log: "Log"
        case .projects: "Project"
        case .ticket: "Ticket"
        case .newTicket: "New ticket"
        }
    }

    var symbol: String {
        switch self {
        case .desk: "tray"
        case .tickets: "list.bullet"
        case .board: "rectangle.split.3x1"
        case .previews: "eye"
        case .specs: "doc.text"
        case .decisions: "flag"
        case .agents: "cpu"
        case .log: "list.bullet.rectangle"
        case .projects: "gearshape"
        case .ticket: "ticket"
        case .newTicket: "plus"
        }
    }
}
