import CoreTransferable
import Foundation

/// What is being dragged on the Scenarios page, carried as a plain string ("scenario:SPEC-24.2") so
/// any drop target can tell where it came from: a scenario, a suggestion from the popup, an expected
/// item (by position), a forbidden title, a rule or a kind.
enum ScenarioDragItem: Equatable {
    case scenario(String)
    case suggestion(String)
    case expected(Int)
    case never(String)
    case rule(String)
    case kind(String)

    init?(_ text: String) {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "scenario": self = .scenario(parts[1])
        case "suggestion": self = .suggestion(parts[1])
        case "expected": guard let index = Int(parts[1]) else { return nil }; self = .expected(index)
        case "never": self = .never(parts[1])
        case "rule": self = .rule(parts[1])
        case "kind": self = .kind(parts[1])
        default: return nil
        }
    }

    var text: String {
        switch self {
        case .scenario(let id): "scenario:\(id)"
        case .suggestion(let title): "suggestion:\(title)"
        case .expected(let index): "expected:\(index)"
        case .never(let title): "never:\(title)"
        case .rule(let id): "rule:\(id)"
        case .kind(let kind): "kind:\(kind)"
        }
    }

    /// The title it carries, if it is a title.
    var title: String? {
        switch self {
        case .suggestion(let title), .never(let title): title
        default: nil
        }
    }

    static func first(in texts: [String]) -> ScenarioDragItem? { texts.lazy.compactMap(ScenarioDragItem.init).first }
}
