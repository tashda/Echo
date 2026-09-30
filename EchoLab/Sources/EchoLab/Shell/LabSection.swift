/// The areas of Echo Labs, in sidebar order.
enum LabSection: String, CaseIterable, Identifiable {
    case ongoing = "Ongoing work"
    case decided = "Decided"
    case areas = "Areas"
    case reference = "Reference"
    case test = "Test"

    var id: String { rawValue }
}

/// Where a piece of design work is in its life (CLAUDE.md, Echo Labs workflow). The owner moves
/// it with Accept, Confirm, comments and Reopen; the agent moves it to In Echo and freezes it.
enum LabStatus: String, Codable, CaseIterable {
    /// The owner has feedback the agent has not acted on yet. Agents read this first.
    case newFeedback = "New feedback"
    /// A playground the owner is judging.
    case judging = "Judging"
    /// The owner accepted the verdict; the agent builds it into Echo.
    case accepted = "Accepted"
    /// Built into Echo; waiting for the owner to check it in the running app.
    case inEcho = "In Echo"
    /// Confirmed in the running app. The agent freezes it into the library.
    case decided = "Decided"

    var section: LabSection { self == .decided ? .decided : .ongoing }

    /// Whose move it is. Feedback the owner sends or a verdict they accept goes straight to the
    /// agent, so the Inbox sorts by turn instead of showing a "New" queue that is always empty.
    enum Turn: String, CaseIterable {
        case you = "For you"
        case agent = "With the agent"
        case done = "Decided"
    }

    var turn: Turn {
        switch self {
        case .judging, .inEcho: .you
        case .newFeedback, .accepted: .agent
        case .decided: .done
        }
    }

    /// What the owner reads. The state file keeps the stored names (`rawValue`).
    var title: String {
        switch self {
        case .newFeedback: "Sent to agent"
        case .judging: "To judge"
        case .accepted: "Accepted"
        case .inEcho: "To check in Echo"
        case .decided: "Decided"
        }
    }

    /// The state file may spell a status as its display name ("In Echo") or as a key
    /// (`inEcho`); both read the same. It is written as the display name.
    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let normalized = text.lowercased().replacingOccurrences(of: " ", with: "")
        guard let status = Self.allCases.first(where: { $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "") == normalized }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Unknown status \"\(text)\". Use New feedback, Judging, Accepted, In Echo or Decided."))
        }
        self = status
    }
}
