import SwiftUI

struct JobQueueView: View {
    var viewModel: JobQueueViewModel
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(TabStore.self) private var tabStore
    @Environment(ActivityEngine.self) private var activityEngine

    @State private var inspectorAutoOpened = false
    @State private var verticalFraction: CGFloat = 0.70
    @State private var horizontalFraction: CGFloat = 0.50
    @State private var showNewJobSheet = false

    /// Whether this view is hosted inside a tab (vs. a detached window).
    private var hostTab: WorkspaceTab? {
        tabStore.tabs.first { $0.jobQueue === viewModel }
    }

    private var canViewJobs: Bool {
        connectionSession?.permissions?.canViewAgentJobs ?? true
    }

    private var canManageJobs: Bool {
        connectionSession?.permissions?.canManageAgent ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
        if !canViewJobs {
            PermissionBanner(
                message: "You do not have permission to view SQL Agent jobs. This requires membership in SQLAgentUserRole or a higher role.",
                severity: .noAccess
            )
        } else if !canManageJobs {
            PermissionBanner(message: "Job management requires the sysadmin or SQLAgentOperatorRole role.")
        }
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
                JobListView(
                    viewModel: viewModel,
                    notificationEngine: environmentState.notificationEngine,
                    permissions: connectionSession?.permissions,
                    onNewJob: { showNewJobSheet = true }
                )
            } second: {
                JobDetailsView(
                    viewModel: viewModel,
                    notificationEngine: environmentState.notificationEngine
                )
            }
        } second: {
            JobHistoryView(viewModel: viewModel)
        }
        .task {
            viewModel.activityEngine = activityEngine
            viewModel.notificationEngine = environmentState.notificationEngine
            if let tab = hostTab {
                viewModel.connectionSessionID = tab.connectionSessionID
            }
            await viewModel.loadInitial()
        }
        .onChange(of: viewModel.selectedHistoryRowID) { _, _ in
            updateInspectorForHistorySelection()
        }
        .onChange(of: viewModel.selectedJobID) { _, _ in
            // Clear history selection when switching jobs
            if viewModel.selectedHistoryRowID != nil {
                viewModel.selectedHistoryRowID = nil
            }
        }
        .onDisappear {
            viewModel.stopActivityPolling()
        }
        .sheet(isPresented: $showNewJobSheet) {
            if let session = connectionSession {
                NewAgentJobSheet(session: session, environmentState: environmentState) {
                    showNewJobSheet = false
                    Task { await viewModel.reloadJobs() }
                }
            }
        }
        } // VStack
    }

    private var connectionSession: ConnectionSession? {
        let sessionID = hostTab?.connectionSessionID ?? viewModel.connectionSessionID
        guard let sessionID else { return nil }
        return environmentState.sessionGroup.activeSessions.first { $0.id == sessionID }
    }

    private func updateInspectorForHistorySelection() {
        let isInTab = hostTab != nil

        guard let row = viewModel.selectedHistoryRow else {
            environmentState.dataInspectorContent = nil
            // Auto-close if we auto-opened it (only in tab context)
            if isInTab && inspectorAutoOpened && appState.showInfoSidebar {
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

        // Auto-open inspector if the setting is enabled (only in tab context)
        if isInTab && projectStore.globalSettings.autoOpenInspectorOnSelection && !appState.showInfoSidebar {
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
