import EchoSense
import SwiftUI

/// Round 28.7: the run note in one look (the editor and the sampler draw it the same way).
struct LabQERunNoteLabel: View {
    let look: LabQERunNoteLook
    let note: QueryRunNote

    @ViewBuilder
    var body: some View {
        let tint = note.isError ? ColorTokens.Status.error : ColorTokens.Status.success
        switch look {
        case .today:
            Text(note.text).font(TypographyTokens.detail).foregroundStyle(tint)
        case .quiet:
            HStack(spacing: SpacingTokens.xxs) {
                Text(note.isError ? "!" : "✓").foregroundStyle(tint).fontWeight(.semibold)
                Text(String(note.text.dropFirst(2))).foregroundStyle(note.isError ? tint : ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.detail)
        case .capsule:
            Text(note.text).font(TypographyTokens.detail).foregroundStyle(tint)
                .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                .background(tint.opacity(0.12), in: Capsule())
        case .glass:
            Text(note.text).font(TypographyTokens.detail).foregroundStyle(tint)
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                .glassEffect(.regular, in: .capsule)
        case .faintCapsule:
            quietLabel(note, tint: tint)
                .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                .background(tint.opacity(0.06), in: Capsule())
        case .outlined:
            Text(note.text).font(TypographyTokens.detail).foregroundStyle(tint)
                .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                .overlay(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1))
        case .solid:
            Text(note.text).font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.Text.onFill)
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.micro)
                .background(tint, in: Capsule())
        case .symbolCapsule:
            symbolLabel(note, tint: tint)
                .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.micro)
                .background(tint.opacity(0.1), in: Capsule())
        case .tintedGlass:
            Text(note.text).font(TypographyTokens.detail).foregroundStyle(tint)
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                .glassEffect(.regular.tint(tint.opacity(0.25)), in: .capsule)
        case .clearGlass:
            quietLabel(note, tint: tint)
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                .glassEffect(.clear, in: .capsule)
        case .glassSymbol:
            symbolLabel(note, tint: tint)
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                .glassEffect(.regular, in: .capsule)
        }
    }

    /// ✓ (or !) in the result's colour, the numbers grey.
    private func quietLabel(_ note: QueryRunNote, tint: Color) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(note.isError ? "!" : "✓").foregroundStyle(tint).fontWeight(.semibold)
            Text(String(note.text.dropFirst(2))).foregroundStyle(note.isError ? tint : ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.detail)
    }

    /// The result's symbol in its colour, the numbers grey.
    private func symbolLabel(_ note: QueryRunNote, tint: Color) -> some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: note.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill").foregroundStyle(tint)
            Text(String(note.text.dropFirst(2))).foregroundStyle(note.isError ? tint : ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.detail)
    }
}

/// Round 28.7 rev 2: every look of the note after a line of code, a success beside an error.
struct LabQERunNoteSampler: View {
    static let width: CGFloat = 640
    static let height: CGFloat = 520

    private let success = QueryRunNote.success(range: NSRange(location: 0, length: 1), rows: 14_870, hasResults: true, duration: 10.1)
    private let failure = QueryRunNote.shortFailure(range: NSRange(location: 0, length: 1), message: LabQESample.serverErrorMessage)

    var body: some View {
        let code = Font(LabQEFonts.nsFont(.sfMono, size: 13, ligatures: false))
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            ForEach(LabQERunNoteLook.allCases, id: \.self) { look in
                HStack(spacing: SpacingTokens.md) {
                    Text(look.rawValue).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                        .frame(width: 200, alignment: .leading)
                    HStack(spacing: LayoutTokens.EditorGutter.runNoteGap) {
                        Text(verbatim: "ORDER BY o.total DESC;").font(code)
                        if let success { LabQERunNoteLabel(look: look, note: success) }
                    }
                    Spacer(minLength: SpacingTokens.xs)
                    if let failure { LabQERunNoteLabel(look: look, note: failure) }
                }
                .lineLimit(1)
                .frame(height: SpacingTokens.lg2)
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.card)
        .workspaceCard()
    }
}
