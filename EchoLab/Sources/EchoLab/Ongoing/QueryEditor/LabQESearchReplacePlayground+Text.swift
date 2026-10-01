import SwiftUI

/// The script with its matches, replacements and the chosen preview drawn into the text.
extension LabQESearchReplacePlayground {
    private var codeFont: NSFont { LabQEFonts.nsFont(.sfMono, size: 12, ligatures: false) }
    private var lineHeight: CGFloat { SpacingTokens.md2 }
    private var gutter: CGFloat { SpacingTokens.lg }

    var code: some View {
        let all = matches
        let currentSpan = all.isEmpty ? nil : all[min(current, all.count - 1)]
        let advance = LabQEFonts.metrics(.sfMono, size: 12).advance
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: SpacingTokens.none) {
                        Text(verbatim: "\(index + 1)").foregroundStyle(ColorTokens.Text.tertiary)
                            .frame(width: gutter - SpacingTokens.xs, alignment: .trailing)
                            .overlay(alignment: .trailing) {
                                if isPreviewing, preview == .withGutter, all.contains(where: { $0.line == index + 1 }) {
                                    Capsule().fill(ColorTokens.Status.success).frame(width: SpacingTokens.xxxs, height: lineHeight - SpacingTokens.xs)
                                        .offset(x: SpacingTokens.xxs)
                                }
                            }
                        Color.clear.frame(width: SpacingTokens.xs, height: 1)
                        Text(attributed(line, line: index + 1, matches: all, current: currentSpan)).fixedSize()
                    }
                    .font(Font(codeFont))
                    .frame(height: lineHeight, alignment: .leading)
                }
            }
            if isPreviewing, preview == .above {
                ForEach(Array(all.enumerated()), id: \.offset) { _, span in
                    Text(replacement).font(Font(codeFont)).foregroundStyle(ColorTokens.Status.success)
                        .padding(.horizontal, SpacingTokens.xxxs)
                        .background(.background, in: RoundedRectangle(cornerRadius: SpacingTokens.nano))
                        .background(ColorTokens.Status.success.opacity(0.14), in: RoundedRectangle(cornerRadius: SpacingTokens.nano))
                        .fixedSize()
                        .offset(x: gutter + CGFloat(span.start) * advance, y: CGFloat(span.line - 1) * lineHeight - lineHeight * 0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
        .animation(motion.hover, value: isPreviewing)
        .animation(motion.hover, value: replacement)
    }

    private func attributed(_ line: String, line number: Int, matches: [LabQESpan], current: LabQESpan?) -> AttributedString {
        let chars = Array(line)
        var marks: [(span: LabQESpan, isMatch: Bool)] = matches.filter { $0.line == number }.map { ($0, true) }
        marks += replaced.filter { $0.line == number }.map { ($0, false) }
        marks.sort { $0.span.start < $1.span.start }
        var result = AttributedString()
        var column = 0
        for mark in marks where mark.span.start >= column && mark.span.end <= chars.count {
            result += AttributedString(String(chars[column..<mark.span.start]))
            let text = String(chars[mark.span.start..<mark.span.end])
            if mark.isMatch {
                result += matchText(text, isCurrent: mark.span == current)
            } else {
                var done = AttributedString(text)
                done.backgroundColor = ColorTokens.Status.success.opacity(0.18)
                result += done
            }
            column = mark.span.end
        }
        result += AttributedString(String(chars[min(column, chars.count)...]))
        return result
    }

    private func matchText(_ text: String, isCurrent: Bool) -> AttributedString {
        let yellow = Color(nsColor: .findHighlightColor)
        func found() -> AttributedString {
            var found = AttributedString(text)
            found.backgroundColor = yellow.opacity(isCurrent ? 1 : 0.35)
            return found
        }
        func old() -> AttributedString {
            var old = AttributedString(text)
            old.strikethroughStyle = Text.LineStyle(pattern: .solid, color: ColorTokens.Status.error)
            old.foregroundColor = ColorTokens.Status.error
            old.backgroundColor = ColorTokens.Status.error.opacity(isCurrent ? 0.2 : 0.1)
            return old
        }
        func new() -> AttributedString {
            var new = AttributedString(replacement)
            new.foregroundColor = ColorTokens.Status.success
            new.backgroundColor = ColorTokens.Status.success.opacity(isCurrent ? 0.28 : 0.14)
            return new
        }
        guard isPreviewing else { return found() }
        switch preview {
        case .noPreview: return found()
        case .above: return old()
        case .inlineDiff: return old() + new()
        case .inPlace, .withGutter: return new()
        case .currentOnly: return isCurrent ? old() + new() : found()
        }
    }
}
