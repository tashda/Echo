import SwiftUI

/// Lays out an As built page from its blueprint: header, stage, then the fixed sections.
struct AsBuiltView: View {
    let area: LabArea
    let page: AsBuiltPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                header
                AsBuiltStage(page: page)
                if !page.behaviours.isEmpty { AsBuiltBehaviourList(items: page.behaviours) }
                if !page.motions.isEmpty { AsBuiltMotionList(items: page.motions) }
                if !page.measurements.isEmpty { AsBuiltMeasurementList(items: page.measurements) }
                if !page.rules.isEmpty { AsBuiltRuleList(items: page.rules) }
                if !page.code.isEmpty { AsBuiltCodeList(paths: page.code) }
            }
            .padding(SpacingTokens.lg)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(area.summary)
                .font(TypographyTokens.prominent)
                .foregroundStyle(ColorTokens.Text.secondary)
            if let verification = page.verification {
                let inApp = verification.level == .runningApp
                Label(
                    inApp ? "Verified in the running app · \(verification.commit) · \(verification.date)"
                          : "Checked against Echo's code, not yet the running app · \(verification.commit) · \(verification.date)",
                    systemImage: inApp ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(inApp ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                if let note = verification.note {
                    Text(note).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
            } else {
                Label("Not checked against Echo yet", systemImage: "questionmark.circle")
                    .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.warning)
            }
        }
    }
}
