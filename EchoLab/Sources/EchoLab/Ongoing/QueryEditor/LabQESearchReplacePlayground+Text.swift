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
                        if isPreviewing, preview.usesLanguage {
                            languageLine(line, line: index + 1, matches: all, current: currentSpan, advance: advance)
                        } else {
                            Text(attributed(line, line: index + 1, matches: all, current: currentSpan)).fixedSize()
                        }
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
        case .languageDiff, .languageQuiet: return found()
        }
    }

    /// PV6, PV7: the line with each match followed by its replacement, marked as round 28.15's
    /// language draws marks (rounded, letters' height, soft and strong).
    private func languageLine(_ line: String, line number: Int, matches: [LabQESpan], current: LabQESpan?, advance: CGFloat) -> some View {
        let language = LabQEMarkLanguage(corner: .oneCorner, tint: .twoSteps, colour: .meaning, height: .letters, floating: .glass)
        let chars = Array(line)
        let quiet = preview == .languageQuiet
        var text = AttributedString()
        var marks: [(start: Int, end: Int, kind: LabQEMarkLanguage.Kind, strong: Bool)] = []
        var column = 0
        var display = 0
        for span in matches.filter({ $0.line == number }) where span.start >= column {
            text += AttributedString(String(chars[column..<span.start]))
            display += span.start - column
            var old = AttributedString(String(chars[span.start..<span.end]))
            old.strikethroughStyle = Text.LineStyle(pattern: .solid, color: quiet ? ColorTokens.Text.tertiary : ColorTokens.Status.error)
            old.foregroundColor = quiet ? ColorTokens.Text.tertiary : ColorTokens.Status.error
            if !quiet { marks.append((display, display + span.end - span.start, .removed, span == current)) }
            text += old + AttributedString(" ")
            display += span.end - span.start + 1
            var new = AttributedString(replacement)
            new.foregroundColor = ColorTokens.Status.success
            marks.append((display, display + replacement.count, .added, span == current))
            text += new
            display += replacement.count
            column = span.end
        }
        text += AttributedString(String(chars[min(column, chars.count)...]))
        let letters = ceil(codeFont.ascender - codeFont.descender) + LayoutTokens.EditorGutter.highlightPadding * 2
        return ZStack(alignment: .leading) {
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                RoundedRectangle(cornerRadius: language.cornerRadius(for: mark.kind, height: letters), style: .continuous)
                    .fill(language.color(for: mark.kind).opacity(language.opacity(for: mark.kind) * (mark.strong ? 1.6 : 1)))
                    .frame(width: CGFloat(mark.end - mark.start) * advance + SpacingTokens.xxxs, height: letters)
                    .offset(x: CGFloat(mark.start) * advance - SpacingTokens.micro)
            }
            Text(text).fixedSize()
        }
    }
}
