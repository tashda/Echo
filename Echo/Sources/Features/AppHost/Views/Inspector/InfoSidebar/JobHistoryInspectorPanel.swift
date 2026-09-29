import SwiftUI

/// An Agent job run as inspector cards (plan I2): the run's details, then its message.
struct JobHistoryInspectorPanel: View {
    let content: JobHistoryInspectorContent

    @Environment(ProjectStore.self) private var projectStore

    var body: some View {
        VStack(alignment: .leading, spacing: projectStore.globalSettings.workspaceGutter.points) {
            InspectorCard(title: content.jobName, subtitle: "Job Execution", systemImage: "clock.arrow.circlepath") {
                InspectorCardRow(label: "Step", value: "\(content.stepId) — \(content.stepName)")
                InspectorCardRow(label: "Status", value: content.status)
                InspectorCardRow(label: "Run Date", value: content.runDate)
                InspectorCardRow(label: "Duration", value: content.duration, isLast: true)
            }
            InspectorCard(title: "Message", systemImage: "text.alignleft") {
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
