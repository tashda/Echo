import SwiftUI

struct PalettePreview: View {
    let palette: SQLEditorPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.gutterAccentColor.opacity(0.4), lineWidth: 1)
                )

            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text("1")
                    Text("2")
                    Text("3")
                }
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(palette.gutterTextColor)
                .frame(width: 46)
                .padding(.vertical, 10)
                .background(palette.gutterBackgroundColor)
                .overlay(
                    Rectangle()
                        .fill(palette.gutterAccentColor.opacity(0.5))
                        .frame(width: 1),
                    alignment: .trailing
                )

                VStack(alignment: .leading, spacing: 6) {
                    codeLine([
                        ("SELECT ", palette.tokens.keyword, true),
                        ("name", palette.tokens.identifier, false),
                        (", ", palette.tokens.plain, false),
                        ("created_at ", palette.tokens.identifier, false),
                        ("FROM ", palette.tokens.keyword, true),
                        ("users", palette.tokens.identifier, false)
                    ])

                    codeLine([
                        ("WHERE ", palette.tokens.keyword, true),
                        ("active ", palette.tokens.identifier, false),
                        ("= ", palette.tokens.operatorSymbol, false),
                        ("TRUE", palette.tokens.number, false)
                    ])

                    codeLine([
                        ("AND ", palette.tokens.keyword, true),
                        ("name", palette.tokens.identifier, false),
                        (" LIKE ", palette.tokens.keyword, true),
                        ("'Ken%'", palette.tokens.string, false)
                    ])
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.currentLineColor.opacity(0.6))
                        .padding(.top, 6)
                        .padding(.bottom, 6)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(6)
        }
        .frame(height: 120)
    }

    private func codeLine(_ segments: [(String, ColorRepresentable, Bool)]) -> Text {
        var attributed = AttributedString()
        for (string, color, isKeyword) in segments {
            var segment = AttributedString(string)
            segment.foregroundColor = color.color
            segment.font = .system(size: 12, weight: isKeyword ? .semibold : .regular, design: .monospaced)
            attributed.append(segment)
        }
        return Text(attributed)
    }
}
