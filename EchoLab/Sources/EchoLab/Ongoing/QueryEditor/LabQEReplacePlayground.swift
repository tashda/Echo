import SwiftUI

/// Round 28.12 rev 3: Replace that works. FB5's glass bar over a small script: type in Find and
/// Replace, press Replace (the current match, then the next) or All, and Reset to start again.
/// Each replace style lays the bar out its own way; RP3 also shows every replacement in place.
struct LabQEReplacePlayground: View {
    static let width: CGFloat = 560
    static let height: CGFloat = 330

    let style: LabQEReplaceStyle

    @State var lines = LabQESample.lines()
    @State var find = "orders"
    @State var replacement = "orders_2026"
    @State var current = 0
    @State var replaced: [LabQESpan] = []
    @State var isReplaceOpen = true

    var matches: [LabQESpan] {
        guard !find.isEmpty else { return [] }
        return lines.enumerated().flatMap { index, line -> [LabQESpan] in
            var spans: [LabQESpan] = []
            var search = line.startIndex..<line.endIndex
            while let range = line.range(of: find, options: .caseInsensitive, range: search) {
                let start = line.distance(from: line.startIndex, to: range.lowerBound)
                spans.append(.init(line: index + 1, start: start, end: start + find.count))
                search = range.upperBound..<line.endIndex
            }
            return spans
        }
    }

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            bar
            code
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.card)
        .workspaceCard()
    }

    func replaceCurrent() {
        let all = matches
        guard !all.isEmpty else { return }
        apply(all[min(current, all.count - 1)])
        current = min(current, max(matches.count - 1, 0))
    }

    func replaceAll() {
        for span in matches.reversed() { apply(span) }
        current = 0
    }

    func reset() {
        lines = LabQESample.lines()
        replaced = []
        current = 0
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

    private var code: some View {
        let font = LabQEFonts.nsFont(.sfMono, size: 12, ligatures: false)
        let advance = LabQEFonts.metrics(.sfMono, size: 12).advance
        let lineHeight: CGFloat = 19
        let gutter: CGFloat = SpacingTokens.lg
        let all = matches
        return ZStack(alignment: .topLeading) {
            ForEach(Array(replaced.enumerated()), id: \.offset) { _, span in
                mark(span, advance: advance, lineHeight: lineHeight, gutter: gutter, colour: ColorTokens.Status.success.opacity(0.18))
            }
            ForEach(Array(all.enumerated()), id: \.offset) { index, span in
                mark(span, advance: advance, lineHeight: lineHeight, gutter: gutter,
                     colour: Color(nsColor: .findHighlightColor).opacity(index == min(current, all.count - 1) ? 1 : 0.35))
                if style == .preview, !replacement.isEmpty {
                    Rectangle().fill(ColorTokens.Status.error).frame(width: CGFloat(span.end - span.start) * advance, height: 1)
                        .offset(x: gutter + CGFloat(span.start) * advance, y: CGFloat(span.line - 1) * lineHeight + lineHeight / 2)
                    Text(replacement).font(Font(font)).foregroundStyle(ColorTokens.Status.success)
                        .padding(.horizontal, SpacingTokens.xxxs)
                        .background(.background, in: RoundedRectangle(cornerRadius: SpacingTokens.nano))
                        .background(ColorTokens.Status.success.opacity(0.14), in: RoundedRectangle(cornerRadius: SpacingTokens.nano))
                        .fixedSize()
                        .offset(x: gutter + CGFloat(span.start) * advance, y: CGFloat(span.line - 1) * lineHeight - lineHeight * 0.8)
                }
            }
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: SpacingTokens.none) {
                        Text(verbatim: "\(index + 1)").foregroundStyle(ColorTokens.Text.tertiary)
                            .frame(width: gutter - SpacingTokens.xs, alignment: .trailing)
                        Color.clear.frame(width: SpacingTokens.xs, height: 1)
                        Text(verbatim: line).fixedSize()
                    }
                    .font(Font(font))
                    .frame(height: lineHeight, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
    }

    private func mark(_ span: LabQESpan, advance: CGFloat, lineHeight: CGFloat, gutter: CGFloat, colour: Color) -> some View {
        RoundedRectangle(cornerRadius: SpacingTokens.nano, style: .continuous).fill(colour)
            .frame(width: CGFloat(span.end - span.start) * advance + SpacingTokens.xxxs, height: lineHeight - SpacingTokens.xxs)
            .offset(x: gutter + CGFloat(span.start) * advance - SpacingTokens.micro, y: CGFloat(span.line - 1) * lineHeight + SpacingTokens.xxxs)
    }
}
