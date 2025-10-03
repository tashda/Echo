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
                        ("SELECT ", palette.tokens.primaryKeyword),
                        ("name", palette.tokens.identifier),
                        (", ", palette.tokens.plain),
                        ("created_at ", palette.tokens.identifier),
                        ("FROM ", palette.tokens.primaryKeyword),
                        ("users", palette.tokens.identifier)
                    ])

                    codeLine([
                        ("WHERE ", palette.tokens.secondaryKeyword),
                        ("active ", palette.tokens.identifier),
                        ("= ", palette.tokens.operatorSymbol),
                        ("TRUE", palette.tokens.number)
                    ])

                    codeLine([
                        ("AND ", palette.tokens.secondaryKeyword),
                        ("name", palette.tokens.identifier),
                        (" LIKE ", palette.tokens.secondaryKeyword),
                        ("'Ken%'", palette.tokens.string)
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

    private func codeLine(_ segments: [(String, ColorRepresentable)]) -> Text {
        segments.reduce(Text("")) { partial, segment in
            partial + Text(segment.0).foregroundColor(segment.1.color)
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
    }
}
