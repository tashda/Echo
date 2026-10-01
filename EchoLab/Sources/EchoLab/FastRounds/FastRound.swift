import Foundation

/// A fast round: the owner's feedback in words and an agent's written analysis of it, with nothing
/// to build. One JSON file in `EchoLab/State/fast-rounds/<slug>.json`, read at runtime, so a new or
/// changed one shows in the Inbox without rebuilding Echo Labs (`Scripts/new-fast-round.py`).
/// The status, the owner's notes and the history live in `lab-state.json` like any other item,
/// under the page id `fast.<slug>`.
struct FastRound: Codable, Equatable, Identifiable {
    struct Section: Codable, Equatable {
        var heading: String
        var body: String
    }

    /// The file name without `.json`.
    var slug = ""
    var title: String
    /// An area's id ("tabs") or title ("Tabs"). Empty or unknown shows as "No area yet".
    var area = ""
    var date = ""
    /// What the owner said, in their words.
    var feedback: String
    /// The verdict in a sentence or two: what is going on and what the agent suggests.
    var summary = ""
    /// What the agent found: how Echo and Echo Labs record it today, what is wrong, why.
    var analysis: [Section] = []
    /// What the agent would do, and why.
    var recommendation = ""
    /// What would change in Echo (files and behaviour) if the owner accepts.
    var changes: [String] = []

    /// Only the title and the owner's words are required; an agent may leave the rest out.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        feedback = try c.decode(String.self, forKey: .feedback)
        slug = try c.decodeIfPresent(String.self, forKey: .slug) ?? ""
        area = try c.decodeIfPresent(String.self, forKey: .area) ?? ""
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        analysis = try c.decodeIfPresent([Section].self, forKey: .analysis) ?? []
        recommendation = try c.decodeIfPresent(String.self, forKey: .recommendation) ?? ""
        changes = try c.decodeIfPresent([String].self, forKey: .changes) ?? []
    }

    var id: String { Self.pageID(slug: slug) }
    static func pageID(slug: String) -> String { "fast.\(slug)" }
}
