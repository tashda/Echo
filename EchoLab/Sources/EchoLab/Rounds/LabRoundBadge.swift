import SwiftUI

/// A round is an identifier, `#17`, not a word. This reads the number out of the names the
/// lab already has ("Round 17", "Rounds 3 to 8", "Server card · round 16", "Round 14 · tab bar")
/// so every place can show it the same way.
enum LabRoundName {
    /// Text with round words taken out ("Review of Server card · round 16" becomes "Review of Server card"),
    /// for feedback saved before rounds became `#N`.
    static func stripped(_ text: String) -> String {
        text.replacing(#/ · [Rr]ound \d+/#, with: "").replacing(#/Round \d+ · /#, with: "")
    }

    /// The identifier ("#17", "#3–8") and the name with the round words taken out.
    static func split(_ text: String) -> (tag: String?, name: String) {
        if let match = text.firstMatch(of: /^Rounds? (\d+)(?: to (\d+))?(?: · )?(.*)$/) {
            let tag = match.2.map { "#\(match.1)–\($0)" } ?? "#\(match.1)"
            return (tag, String(match.3))
        }
        if let match = text.firstMatch(of: /^(.*?) · round (\d+)$/) {
            return ("#\(match.2)", String(match.1))
        }
        return (nil, text)
    }
}

/// `#17` as a small monospaced pill.
struct LabRoundBadge: View {
    let tag: String
    var size: CGFloat = 11
    var body: some View {
        Text(tag)
            .font(.system(size: size, weight: .semibold, design: .monospaced))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, size * 0.55).frame(height: size * 1.65)
            .background(ColorTokens.Surface.hover, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A page or round title with its round identifier as a badge in front.
struct LabRoundTitle: View {
    let text: String
    var font: Font = TypographyTokens.standard.weight(.semibold)
    var badgeSize: CGFloat = 11

    var body: some View {
        let parts = LabRoundName.split(text)
        HStack(spacing: 6) {
            if let tag = parts.tag { LabRoundBadge(tag: tag, size: badgeSize) }
            Text(parts.name.isEmpty ? text : parts.name).font(font).lineLimit(1)
        }
    }
}

/// A round's identifier as a badge; rounds without a number keep their words.
struct LabRoundLabel: View {
    let round: LabRounds.Info
    var body: some View {
        if let tag = LabRoundName.split(round.label).tag {
            LabRoundBadge(tag: tag)
        } else {
            Text(round.label).font(TypographyTokens.detail).foregroundStyle(.secondary)
        }
    }
}
