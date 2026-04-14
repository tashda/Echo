import SwiftUI
import SQLServerKit

struct JobListView: View {
    var viewModel: JobQueueViewModel
    let notificationEngine: NotificationEngine?
    var permissions: (any DatabasePermissionProviding)?
    var onNewJob: (() -> Void)?
    @State private var tableSelection: Set<String> = []
    @State private var sortOrder: [KeyPathComparator<JobQueueViewModel.JobRow>] = [
        .init(\.name, order: .forward)
    ]

    private var sortedJobs: [JobQueueViewModel.JobRow] {
        viewModel.jobs.sorted(using: sortOrder)
    }

    @State private var showAlertSheet = false
    @State private var showProxySheet = false
    @State private var showCategorySheet = false
    @State private var showNewAlertSheet = false
    @State private var editingAlert: JobQueueViewModel.AlertRow?
    @State private var editingProxy: JobQueueViewModel.ProxyRow?
    @State private var pendingDeleteAlertName: String?
    @State private var showDeleteAlertAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Jobs").font(TypographyTokens.headline)
                Spacer()
                Menu {
                    Button {
                        onNewJob?()
                    } label: {
                        Label("New Job", systemImage: "clock")
                    }

                    Divider()

                    Button {
                        showNewAlertSheet = true
                    } label: {
                        Label("New Alert", systemImage: "bell")
                    }

                    Button {
                        showProxySheet = true
                    } label: {
                        Label("New Proxy", systemImage: "person.badge.key")
                    }

                    Divider()

                    Button {
                        showCategorySheet = true
                    } label: {
                        Label("Manage Categories", systemImage: "folder")
                    }

                    Divider()

                    Button {
                        Task { await viewModel.reloadJobs() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Agent management actions")
            }
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)

            Table(of: JobQueueViewModel.JobRow.self, selection: $tableSelection, sortOrder: $sortOrder) {
                TableColumn("Enabled", value: \.enabledSortKey) { job in
                    if viewModel.runningJobNames.contains(job.name) {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                            .foregroundStyle(job.enabled ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                    }
                }.width(28)
                TableColumn("Name", value: \.name) { job in
                    Text(job.name)
                        .font(TypographyTokens.Table.name)
                }
                TableColumn("Owner", value: \.ownerSortKey) { job in
                    Text(job.owner ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(job.owner == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
                TableColumn("Category", value: \.categorySortKey) { job in
                    Text(job.category ?? "\u{2014}")
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(job.category == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
                TableColumn("Status", value: \.statusSortKey) { job in
                    let isRunning = viewModel.runningJobNames.contains(job.name)
                    Text(isRunning ? "Running" : "Idle")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(isRunning ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
                }
                TableColumn("Last Run", value: \.lastRunDateSortKey) { job in
                    Text(job.lastRunDate ?? "\u{2014}")
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(job.lastRunDate == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
                TableColumn("Last Outcome", value: \.outcomeSortKey) { job in
                    Text(job.lastOutcome ?? "\u{2014}")
                        .font(TypographyTokens.Table.status)
                        .foregroundStyle(jobOutcomeColor(job.lastOutcome))
                }
                TableColumn("Next Run", value: \.nextRunSortKey) { job in
                    Text(job.nextRun ?? "—")
                        .font(TypographyTokens.Table.date)
                        .foregroundStyle(job.nextRun == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                }
            } rows: {
                ForEach(sortedJobs) { job in TableRow(job) }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .tableColumnAutoResize()
            .contextMenu(forSelectionType: String.self) { items in
                if let id = items.first {
                    let jobIsRunning = viewModel.jobs.first(where: { $0.id == id }).map { viewModel.runningJobNames.contains($0.name) } ?? false

                    if !jobIsRunning {
                        Button {
                            Task {
                                viewModel.selectedJobID = id
                                let jobName = viewModel.jobs.first(where: { $0.id == id })?.name ?? "Job"
                                await viewModel.startSelectedJob()
                                if viewModel.errorMessage == nil {
                                    notificationEngine?.post(.jobStarted(name: jobName))
                                }
                            }
                        } label: {
                            Label("Start Job", systemImage: "play.fill")
                        }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    }
                    if jobIsRunning {
                        Button {
                            Task {
                                viewModel.selectedJobID = id
                                let jobName = viewModel.jobs.first(where: { $0.id == id })?.name ?? "Job"
                                await viewModel.stopSelectedJob()
                                if viewModel.errorMessage == nil {
                                    notificationEngine?.post(.jobStopped(name: jobName))
                                }
                            }
                        } label: {
                            Label("Stop Job", systemImage: "stop.fill")
                        }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    }
                    Divider()
                    Button { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(true) } } label: { Label("Enable Job", systemImage: "checkmark.circle") }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    Button { Task { viewModel.selectedJobID = id; await viewModel.setSelectedJobEnabled(false) } } label: { Label("Disable Job", systemImage: "nosign") }
                        .disabled(!(permissions?.canManageAgent ?? true))
                } else {
                    // Empty space context menu
                    Button { onNewJob?() } label: { Label("New Job", systemImage: "briefcase") }
                        .disabled(!(permissions?.canManageAgent ?? true))
                    Button { Task { await viewModel.reloadJobs() } } label: { Label("Refresh Jobs", systemImage: "arrow.clockwise") }
                }
            }
            .onChange(of: tableSelection) { _, newValue in
                let newID = newValue.first
                if viewModel.selectedJobID != newID {
                    viewModel.selectedJobID = newID
                }
            }
            .onChange(of: viewModel.selectedJobID) { _, newID in
                let expected: Set<String> = newID.map { [$0] } ?? []
                if tableSelection != expected {
                    tableSelection = expected
                }
            }
            .onAppear {
                if let id = viewModel.selectedJobID {
                    tableSelection = [id]
                }
            }
            .background(alertSheets)
        }
    }

    // MARK: - Alert Sheets

    private var alertSheets: some View {
        Group {
            EmptyView()
        }
        .sheet(isPresented: $showNewAlertSheet) {
            AgentAlertEditorSheet(
                databaseNames: viewModel.databaseNames
            ) { name, severity, messageId, db, keyword, enabled in
                let error = await viewModel.createAlert(name: name, severity: severity, messageId: messageId, databaseName: db, eventDescriptionKeyword: keyword, enabled: enabled)
                if error == nil { showNewAlertSheet = false }
                return error
            } onCancel: {
                showNewAlertSheet = false
            }
        }
        .sheet(item: $editingAlert) { alert in
            let alertInfo = SQLServerAgentAlertInfo(
                name: alert.name,
                severity: alert.severity,
                messageId: alert.messageId,
                databaseName: alert.databaseName,
                enabled: alert.enabled
            )
            AgentAlertEditorSheet(
                alert: alertInfo,
                databaseNames: viewModel.databaseNames
            ) { name, severity, messageId, db, keyword, enabled in
                let error = await viewModel.updateAlert(originalName: alert.name, name: name, severity: severity, messageId: messageId, databaseName: db, eventDescriptionKeyword: keyword, enabled: enabled)
                if error == nil { editingAlert = nil }
                return error
            } onCancel: {
                editingAlert = nil
            }
        }
        .sheet(isPresented: $showProxySheet) {
            AgentProxyEditorSheet(
                availableLogins: viewModel.logins,
                onSave: { name, credential, enabled in
                    let error = await viewModel.createProxy(name: name, credentialName: credential, description: nil, enabled: enabled)
                    if error == nil { showProxySheet = false }
                    return error
                },
                onCancel: { showProxySheet = false }
            )
        }
        .sheet(item: $editingProxy) { proxy in
            AgentProxyEditorSheet(
                proxyName: proxy.name,
                credentialName: proxy.credentialName ?? "",
                enabled: proxy.enabled,
                isEditing: true,
                availableLogins: viewModel.logins,
                onSave: { _, _, _ in
                    editingProxy = nil
                    return nil
                },
                onGrantLogin: { proxy, login in
                    await viewModel.grantLoginToProxy(proxyName: proxy, loginName: login)
                },
                onRevokeLogin: { proxy, login in
                    await viewModel.revokeLoginFromProxy(proxyName: proxy, loginName: login)
                },
                onGrantSubsystem: { proxy, subsystem in
                    await viewModel.grantProxyToSubsystem(proxyName: proxy, subsystem: subsystem)
                },
                onRevokeSubsystem: { proxy, subsystem in
                    await viewModel.revokeProxyFromSubsystem(proxyName: proxy, subsystem: subsystem)
                },
                loadSubsystems: { proxy in
                    await viewModel.loadProxySubsystems(proxyName: proxy)
                },
                loadLogins: { proxy in
                    await viewModel.loadProxyLogins(proxyName: proxy)
                },
                onCancel: { editingProxy = nil }
            )
        }
        .sheet(isPresented: $showCategorySheet) {
            AgentCategoryManagerSheet(
                categories: viewModel.categories,
                onCreate: { name in await viewModel.createCategory(name: name) },
                onRename: { old, new in await viewModel.renameCategory(name: old, newName: new) },
                onDelete: { name in await viewModel.deleteCategoryAction(name: name) },
                onDismiss: { showCategorySheet = false }
            )
        }
        .alert("Delete Alert?", isPresented: $showDeleteAlertAlert) {
            Button("Cancel", role: .cancel) { pendingDeleteAlertName = nil }
            Button("Delete", role: .destructive) {
                guard let name = pendingDeleteAlertName else { return }
                pendingDeleteAlertName = nil
                Task { await viewModel.deleteAlert(name: name) }
            }
        } message: {
            if let name = pendingDeleteAlertName {
                Text("Are you sure you want to delete alert \"\(name)\"? This action cannot be undone.")
            }
        }
    }

    private func jobOutcomeColor(_ outcome: String?) -> Color {
        switch outcome {
        case "Succeeded": return ColorTokens.Status.success
        case "Failed": return ColorTokens.Status.error
        case "In Progress": return ColorTokens.Status.warning
        case nil: return ColorTokens.Text.tertiary
        default: return ColorTokens.Text.secondary
        }
    }
}
