import SwiftUI

/// An Always Encrypted value in Table Data (round 29): a dimmed lock and "Encrypted", never
/// editable. In edit mode a double-click explains why, naming the column master key (ED1).
struct TableDataEncryptedCell: View {
    let columnName: String
    let encryption: ColumnInfo.Encryption
    let explainsOnDoubleClick: Bool

    @State private var showsExplanation = false

    var body: some View {
        Label("Encrypted", systemImage: "lock.fill")
            .font(TypographyTokens.detail.monospaced())
            .foregroundStyle(ColorTokens.Text.tertiary)
            .lineLimit(1)
            .padding(.horizontal, SpacingTokens.xs)
            .frame(minWidth: 120, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if explainsOnDoubleClick { showsExplanation = true }
            }
            .popover(isPresented: $showsExplanation, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Label("Can't edit an encrypted value", systemImage: "lock.fill")
                        .font(TypographyTokens.standard.weight(.semibold))
                    Text(Self.explanation(columnName: columnName, encryption: encryption))
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SpacingTokens.sm)
                .frame(width: 280, alignment: .leading)
            }
            .help("Always Encrypted · \(encryption.typeName)")
    }

    nonisolated static func explanation(columnName: String, encryption: ColumnInfo.Encryption) -> String {
        if let key = encryption.keyDescription {
            return "Changing \(columnName) needs the column master key (\(key)), which Echo cannot use."
        }
        return "Changing \(columnName) needs its column master key, which Echo cannot use."
    }
}
