import SwiftUI

/// How the results card says what state it is in (round 41.3, EP1): a banner at the top left
/// with a symbol (or a spinner), a title, a line of detail and, below, anything else the state
/// needs (chips, actions). Read from the top left like everything else in the card.
struct ResultsStateBanner<Extra: View>: View {
    enum Mark {
        case symbol(String, tint: Color)
        case progress
    }

    let mark: Mark
    let title: String
    let detail: String?
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            markView
                .frame(width: SpacingTokens.md2, height: SpacingTokens.md2)
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                Text(title)
                    .font(TypographyTokens.standard.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                extra()
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var markView: some View {
        switch mark {
        case .symbol(let name, let tint):
            Image(systemName: name)
                .font(TypographyTokens.title3)
                .foregroundStyle(tint)
        case .progress:
            ProgressView().controlSize(.small)
        }
    }
}

extension ResultsStateBanner where Extra == EmptyView {
    init(mark: Mark, title: String, detail: String?) {
        self.init(mark: mark, title: title, detail: detail, extra: { EmptyView() })
    }
}
