import Foundation

/// Command-line arguments split into positionals, `--key value` options (repeatable) and boolean flags.
struct Args {
    var positionals: [String] = []
    var options: [String: [String]] = [:]
    var flags: Set<String> = []

    /// Flags that never take a value. Everything else written as `--name` consumes the next word.
    static let booleanFlags: Set<String> = ["json", "dry-run", "help", "all", "submit", "open", "force", "no-sync", "quiet", "enqueue", "no-workspace", "sketch-flag"]

    init(_ raw: [String]) {
        var i = 0
        while i < raw.count {
            let word = raw[i]
            if word == "--" { positionals += raw[(i + 1)...]; break }
            if word.hasPrefix("--") {
                var name = String(word.dropFirst(2)), value: String?
                if let eq = name.firstIndex(of: "=") { value = String(name[name.index(after: eq)...]); name = String(name[..<eq]) }
                if Self.booleanFlags.contains(name) { flags.insert(name) }
                else if let value { options[name, default: []].append(value) }
                else if i + 1 < raw.count { options[name, default: []].append(raw[i + 1]); i += 1 }
                else { flags.insert(name) }
            } else { positionals.append(word) }
            i += 1
        }
    }

    func option(_ name: String) -> String? { options[name]?.last }
    func list(_ name: String) -> [String] { options[name] ?? [] }
    func flag(_ name: String) -> Bool { flags.contains(name) }
    func pos(_ i: Int) -> String? { i < positionals.count ? positionals[i] : nil }
    /// Everything after the first `count` positionals, joined (so `hatch note #1 some words` works without quotes).
    func rest(from count: Int) -> String { positionals.dropFirst(count).joined(separator: " ") }
}

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ d: String) { description = d }
}
