import SwiftUI

/// Round 28.13: search and replace that works, on FB5's glass with RP1's chevron. Type in Find
/// and Replace (whole words), open Replace with the chevron (or the buttons on the left), press
/// Replace or Replace All, and watch the preview in the text. ↺ resets.
struct LabQESearchReplacePlayground: View {
    static let width: CGFloat = 620
    static let height: CGFloat = 400

    let preview: LabQEReplacePreview
    let opening: LabQEReplaceOpening
    let shortcuts: LabQEFindShortcuts
    /// The All previews exhibit: no bar, Replace open, only the text.
    var compact = false

    @Environment(\.echoMotion) var motion
    @Namespace var glassSpace
    @State var isFindOpen = true
    @State var isReplaceOpen = false
    @State var lines = LabQESample.lines()
    @State var find = "orders"
    @State var replacement = "orders_2026"
    @State var current = 0
    @State var replaced: [LabQESpan] = []
    @State var status: String?
    let commands = LabQESearchCommands.shared

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            if !compact {
                ZStack(alignment: .top) {
                    if isFindOpen { bar.transition(.opacity) }
                }
                .frame(maxWidth: .infinity, minHeight: SpacingTokens.xxl, alignment: .top)
            }
            code
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.card)
        .workspaceCard()
        .onAppear { if compact { isReplaceOpen = true } }
        .onChange(of: commands.openFind) { _, _ in
            // FO0: ⌘F goes to Find and leaves Replace as it is.
            withAnimation(opening.animation(motion)) { isFindOpen = true }
        }
        .onChange(of: commands.openReplace) { _, _ in
            withAnimation(opening.animation(motion)) { isFindOpen = true; isReplaceOpen = true }
        }
    }

    /// Whole-word matches of Find, in order.
    var matches: [LabQESpan] {
        guard !find.isEmpty else { return [] }
        let word: (Character) -> Bool = { $0.isLetter || $0.isNumber || $0 == "_" }
        return lines.enumerated().flatMap { index, line -> [LabQESpan] in
            let chars = Array(line)
            let needle = Array(find.lowercased())
            var spans: [LabQESpan] = []
            var start = 0
            while start + needle.count <= chars.count {
                let slice = chars[start..<start + needle.count].map { Character($0.lowercased()) }
                let before = start == 0 || !word(chars[start - 1])
                let after = start + needle.count == chars.count || !word(chars[start + needle.count])
                if slice == needle, before, after {
                    spans.append(.init(line: index + 1, start: start, end: start + needle.count))
                    start += needle.count
                } else {
                    start += 1
                }
            }
            return spans
        }
    }

    var isPreviewing: Bool { isReplaceOpen && !replacement.isEmpty && preview != .noPreview }

    func replaceCurrent() {
        let all = matches
        guard !all.isEmpty else { return }
        apply(all[min(current, all.count - 1)])
        current = min(current, max(matches.count - 1, 0))
        status = "Replaced 1"
    }

    func replaceAll() {
        let count = matches.count
        for span in matches.reversed() { apply(span) }
        current = 0
        status = "Replaced \(count)"
    }

    func reset() {
        lines = LabQESample.lines()
        replaced = []
        current = 0
        status = nil
    }

    private func apply(_ span: LabQESpan) {
        var line = Array(lines[span.line - 1])
        line.replaceSubrange(span.start..<span.end, with: Array(replacement))
        lines[span.line - 1] = String(line)
        let delta = replacement.count - (span.end - span.start)
        replaced = replaced.map { other in
            other.line == span.line && other.start > span.start ? .init(line: other.line, start: other.start + delta, end: other.end + delta) : other
        } + [.init(line: span.line, start: span.start, end: span.start + replacement.count)]
    }
}
