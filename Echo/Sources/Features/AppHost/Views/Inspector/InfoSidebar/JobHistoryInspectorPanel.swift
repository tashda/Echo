import SwiftUI

/// An Agent job run as inspector cards (plan I2): the run's details, then its message.
struct JobHistoryInspectorPanel: View {
    let content: JobHistoryInspectorContent

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            InspectorSection(title: content.jobName, subtitle: "Job Execution", systemImage: "clock.arrow.circlepath") {
                InspectorSectionRow(label: "Step", value: "\(content.stepId) — \(content.stepName)")
                InspectorSectionRow(label: "Status", value: content.status)
                InspectorSectionRow(label: "Run Date", value: content.runDate)
                InspectorSectionRow(label: "Duration", value: content.duration, isLast: true)
            }
            InspectorSection(title: "Message", systemImage: "text.alignleft") {
                Button { copyToGeneralPasteboard(content.message) } label: { Label("Copy", systemImage: "doc.on.doc") }
            } content: {
                Text(content.message)
                    .font(TypographyTokens.code)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
