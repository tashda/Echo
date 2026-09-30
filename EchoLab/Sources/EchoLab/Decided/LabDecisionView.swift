import SwiftUI

/// A decision's page: reasoning on top, then each option live with its verdict and its code.
struct LabDecisionView: View {
    let decision: LabDecision

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                header
                ForEach(decision.options) { option in
                    LabDecisionOptionView(option: option)
                }
            }
            .padding(SpacingTokens.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Decided \(decision.decidedOn)")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            if let replacement = decision.supersededBy {
                Text("Superseded by \(replacement)")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Status.warning)
            }
            Text(decision.reasoning).font(TypographyTokens.standard)
            if !decision.shipped.isEmpty {
                Text("In Echo: " + decision.shipped.joined(separator: ", "))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }
}
