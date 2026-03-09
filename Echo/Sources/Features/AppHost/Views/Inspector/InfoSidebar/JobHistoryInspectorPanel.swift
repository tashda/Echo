import SwiftUI

struct JobHistoryInspectorPanel: View {
    let content: JobHistoryInspectorContent

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Job Execution")
                .font(TypographyTokens.prominent.weight(.semibold))

            GroupBox {
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    LabeledContent("Job", value: content.jobName)
                    Divider()
                    LabeledContent("Step", value: "\(content.stepId) — \(content.stepName)")
                    Divider()
                    LabeledContent("Status", value: content.status)
                    Divider()
                    LabeledContent("Run Date", value: content.runDate)
                    Divider()
                    LabeledContent("Duration", value: content.duration)
                }
                .padding(.vertical, SpacingTokens.xs)
            }

            Text("Execution Message")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(content.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.sm)
                .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
