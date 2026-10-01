import SwiftUI

/// Round 43.1 (PV1, PS0): a small editor pinned above Settings › Editor that follows every setting
/// on the page: the text, the gutter, the statement at the caret with its Run arrow, the word at
/// the caret, marks, wrapping, the error note and the outline edge. Sample data, no app state.
struct EditorSettingsPreview: View {
    let settings: GlobalSettings

    private static let lines = [
        "select bagno, Centre",
        "from ba_tbl",
        "where uniqueBagID <> 123456 and seal is not null and Centre = '10' and state = 0",
        "",
        "update aml_checkpoint",
        "set keyValue = '20260801'",
    ]
    private static let keywords: Set<String> = ["select", "from", "where", "update", "set", "and", "is", "not", "null"]

    private var fontSize: Double { settings.defaultEditorFontSize }
    private var lineHeight: CGFloat { fontSize * settings.defaultEditorLineHeight }
    private var markOpacity: Double { 0.12 * Double(settings.editorMarkStrength.multiplier) }

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            if settings.editorShowLineNumbers { gutter }
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                ForEach(Array(Self.lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: SpacingTokens.xs) {
                        lineText(line, index: index)
                        if index == 2, settings.editorEnableLiveValidation { errorNote }
                    }
                    .frame(minHeight: lineHeight, alignment: .leading)
                    .background(alignment: .leading) {
                        if settings.editorStatementFocus, index <= 2 {
                            ColorTokens.accent.opacity(0.06 * Double(settings.editorMarkStrength.multiplier))
                                .padding(.leading, -SpacingTokens.xxs)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, SpacingTokens.xs)
            Spacer(minLength: 0)
            if settings.editorOutlineEdge { outlineEdge }
        }
        .padding(.vertical, SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.card)
        .clipShape(.rect(cornerRadius: SpacingTokens.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous)
                .strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }

    private var errorNote: some View {
        Label(settings.editorErrorRunNoteShowsMessage ? "Invalid column name 'seal'" : "Error",
              systemImage: "exclamationmark.circle.fill")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Status.error)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: SpacingTokens.md2)
            .glassEffect(.regular, in: .capsule)
    }

    private var outlineEdge: some View {
        VStack(spacing: SpacingTokens.xxxs) {
            Capsule().fill(ColorTokens.accent.opacity(0.5)).frame(height: SpacingTokens.lg)
            Capsule().fill(ColorTokens.Status.error).frame(height: SpacingTokens.xxs)
            Spacer()
        }
        .frame(width: SpacingTokens.xxs)
        .padding(.vertical, SpacingTokens.xs)
        .padding(.trailing, SpacingTokens.xxs)
    }

    private func lineText(_ line: String, index: Int) -> some View {
        let words = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        let text = Text(words.enumerated().reduce(AttributedString()) { result, pair in
            var part = AttributedString((pair.offset == 0 ? "" : " ") + pair.element)
            part.font = Font(NSFont(name: settings.defaultEditorFontFamily, size: fontSize)
                             ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular))
            if Self.keywords.contains(pair.element.lowercased()) {
                part.foregroundColor = Color(nsColor: .systemBlue)
            } else if pair.element.hasPrefix("'") || Double(pair.element) != nil {
                part.foregroundColor = Color(nsColor: .systemRed)
            }
            return result + part
        })
        return text
            .lineLimit(settings.editorWrapLines ? nil : 1)
            .fixedSize(horizontal: !settings.editorWrapLines, vertical: true)
            .background(alignment: .leading) {
                if settings.editorHighlightSelectedSymbol, index == 1 {
                    let height = fontSize * 1.3
                    RoundedRectangle(cornerRadius: settings.editorMarkCorners.radius(forHeight: height), style: .continuous)
                        .fill(ColorTokens.accent.opacity(markOpacity))
                        .frame(width: fontSize * 3.6, height: height)
                        .offset(x: fontSize * 2.9)
                }
            }
    }

    private var gutter: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.none) {
            ForEach(0..<Self.lines.count, id: \.self) { index in
                HStack(spacing: SpacingTokens.xxs) {
                    if settings.editorStatementFocus, index == 0 {
                        Image(systemName: "play.fill").font(TypographyTokens.compact).foregroundStyle(ColorTokens.accent)
                    }
                    Text("\(index + 1)")
                        .font(.system(size: fontSize * 0.85, design: .monospaced))
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .frame(height: lineHeight, alignment: .center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(width: SpacingTokens.xl2 + SpacingTokens.xs, alignment: .trailing)
        .frame(maxHeight: .infinity, alignment: .top)
        .background { gutterBackground }
    }

    @ViewBuilder
    private var gutterBackground: some View {
        switch settings.editorGutterStyle {
        case .subtle: Color.clear
        case .tinted: ColorTokens.Sidebar.hoverFill
        case .lane:
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous).fill(ColorTokens.Sidebar.hoverFill)
                .padding(.horizontal, SpacingTokens.xxs).padding(.vertical, -SpacingTokens.xxs)
        case .hairline:
            HStack { Spacer(); Rectangle().fill(ColorTokens.Separator.primary).frame(width: 0.5) }
        }
    }
}
