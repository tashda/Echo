import SwiftUI

struct JobHistoryInspectorPanel: View {
    let content: JobHistoryInspectorContent

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Job Execution")
                .font(TypographyTokens.prominent.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    PropertyRow(title: "Job") {
                        Text(content.jobName)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    Divider()
                    PropertyRow(title: "Step") {
                        Text("\(content.stepId) — \(content.stepName)")
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    Divider()
                    PropertyRow(title: "Status") {
                        Text(content.status)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    Divider()
                    PropertyRow(title: "Run Date") {
                        Text(content.runDate)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    Divider()
                    PropertyRow(title: "Duration") {
                        Text(content.duration)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
                .padding(.vertical, SpacingTokens.xs)
            }

            Text("Execution Message")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)

            Text(content.message)
                .font(TypographyTokens.code)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
