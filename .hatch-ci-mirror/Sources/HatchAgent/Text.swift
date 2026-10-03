import Foundation

/// Small text helpers shared by the brief and the prompts. Token cost matters, so long text is cut with a note.
enum Text {
    /// Cuts `s` to `max` characters and says how much was left out.
    static func clip(_ s: String, _ max: Int) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        return String(t.prefix(max)).trimmingCharacters(in: .whitespacesAndNewlines) + " ... [+\(t.count - max) characters cut]"
    }

    static func oneLine(_ s: String, _ max: Int) -> String {
        clip(s.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " "), max)
    }

    static func indent(_ s: String, _ n: Int = 2) -> String {
        let pad = String(repeating: " ", count: n)
        return s.split(separator: "\n", omittingEmptySubsequences: false).map { pad + $0 }.joined(separator: "\n")
    }
}
