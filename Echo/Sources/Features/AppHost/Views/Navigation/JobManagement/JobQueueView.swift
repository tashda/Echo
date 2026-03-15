import SwiftUI

struct JobQueueView: View {
    @ObservedObject var viewModel: JobQueueViewModel
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appState: AppState
    @Environment(ProjectStore.self) private var projectStore

    @State private var inspectorAutoOpened = false
    @State private var verticalFraction: CGFloat = 0.70
    @State private var horizontalFraction: CGFloat = 0.50

    var body: some View {
        NativeSplitView(
            isVertical: false,
            firstMinFraction: 0.30,
            secondMinFraction: 0.15,
            fraction: $verticalFraction
        ) {
            NativeSplitView(
                isVertical: true,
                firstMinFraction: 0.25,
                secondMinFraction: 0.25,
                fraction: $horizontalFraction
            ) {
                JobListView(viewModel: viewModel, notificationEngine: environmentState.notificationEngine)
            } second: {
                JobDetailsView(
                    viewModel: viewModel,
                    notificationEngine: environmentState.notificationEngine
                )
            }
        } second: {
            JobHistoryView(viewModel: viewModel)
        }
        .task { await viewModel.loadInitial() }
        .onChange(of: viewModel.selectedHistoryRowID) { _, _ in
            updateInspectorForHistorySelection()
        }
        .onChange(of: viewModel.selectedJobID) { _, _ in
            // Clear history selection when switching jobs
            if viewModel.selectedHistoryRowID != nil {
                viewModel.selectedHistoryRowID = nil
            }
        }
    }

    private func updateInspectorForHistorySelection() {
        guard let row = viewModel.selectedHistoryRow else {
            environmentState.dataInspectorContent = nil
            // Auto-close if we auto-opened it
            if inspectorAutoOpened && appState.showInfoSidebar {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.showInfoSidebar = false
                }
                inspectorAutoOpened = false
            }
            return
        }

        let dateStr = formatAgentDate(row.runDate, row.runTime)
        let durationStr = formatDuration(row.runDuration)
        let statusStr: String = {
            switch row.status {
            case 0: return "Failed"
            case 1: return "Succeeded"
            case 2: return "Retry"
            case 3: return "Canceled"
            case 4: return "In Progress"
            default: return "Unknown"
            }
        }()

        environmentState.dataInspectorContent = .jobHistory(
            JobHistoryInspectorContent(
                jobName: row.jobName,
                stepId: row.stepId,
                stepName: row.stepName,
                status: statusStr,
                runDate: dateStr,
                duration: durationStr,
                message: row.message
            )
        )

        // Auto-open inspector if the setting is enabled and it wasn't already open
        if projectStore.globalSettings.autoOpenInspectorOnSelection && !appState.showInfoSidebar {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.showInfoSidebar = true
            }
            inspectorAutoOpened = true
        }
    }

    private func formatAgentDate(_ dateInt: Int, _ timeInt: Int) -> String {
        guard dateInt > 0 else { return "—" }
        let yyyy = dateInt / 10000
        let mm = (dateInt / 100) % 100
        let dd = dateInt % 100
        let hh = timeInt / 10000
        let mi = (timeInt / 100) % 100
        let ss = timeInt % 100
        let comps = DateComponents(year: yyyy, month: mm, day: dd, hour: hh, minute: mi, second: ss)
        if let date = Calendar(identifier: .gregorian).date(from: comps) {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .medium
            return fmt.string(from: date)
        }
        return "—"
    }

    private func formatDuration(_ runDuration: Int) -> String {
        let hours = runDuration / 10000
        let minutes = (runDuration / 100) % 100
        let seconds = runDuration % 100
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
