import Foundation
import HatchCore

/// Agents read JSON (`--json`), people read text. Both come from the same call so they cannot drift apart.
struct Output {
    let json: Bool
    func emit(_ value: JSONValue, text: @autoclosure () -> String) {
        print(json ? value.jsonString(pretty: true) : text())
    }
    func line(_ s: String) { print(s) }
}

extension Ticket {
    var asJSON: JSONValue {
        [
            "number": .string(displayNumber), "id": .int(id), "type": .string(type.rawValue), "status": .string(status.rawValue),
            "turn": .string(turn.rawValue), "title": .string(title), "area": area.map { .string($0) } ?? .null,
            "revision": .int(revision), "takenBy": takenBy.map { .string($0) } ?? .null,
        ]
    }
    var oneLine: String { "\(displayNumber)  \(type.displayName.padding(toLength: 9, withPad: " ", startingAt: 0)) \(status.displayName.padding(toLength: 13, withPad: " ", startingAt: 0)) \(title)" }
}

enum Home {
    /// Hatch's data folder: HATCH_HOME, else the platform default (same rule as the app and the Stage).
    static var directory: String {
        if let h = ProcessInfo.processInfo.environment["HATCH_HOME"], !h.isEmpty { return h }
        #if os(macOS)
        return NSHomeDirectory() + "/Library/Application Support/Hatch"
        #else
        return NSHomeDirectory() + "/.local/share/hatch"
        #endif
    }
    static var databasePath: String { directory + "/hatch.sqlite" }
}
