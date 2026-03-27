import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    // MARK: - Database Snapshots Folder (MSSQL Server-Level)

    @ViewBuilder
    func databaseSnapshotsFolderSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.databaseSnapshotsExpandedBySession[connID] ?? false
        let snapshots = viewModel.databaseSnapshotsBySession[connID] ?? []
        let isLoading = viewModel.databaseSnapshotsLoadingBySession[connID] ?? false
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { _ in
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    viewModel.databaseSnapshotsExpandedBySession[connID] = !isExpanded
                }
                if !isExpanded && snapshots.isEmpty {
                    loadDatabaseSnapshots(session: session)
                }
            }
        )

        Button {
            expandedBinding.wrappedValue.toggle()
        } label: {
            SidebarRow(
                depth: 0,
                icon: .system("camera"),
                label: "Database Snapshots",
                isExpanded: expandedBinding,
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Database Snapshots", colored: colored)
            ) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text("\(snapshots.count)")
                    .font(SidebarRowConstants.trailingFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .contextMenu {
            Button {
                loadDatabaseSnapshots(session: session)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                sheetState.createSnapshotConnectionID = connID
                sheetState.showCreateSnapshotSheet = true
            } label: {
                Label("New Snapshot...", systemImage: "camera.badge.ellipsis")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if isExpanded {
            if snapshots.isEmpty {
                SidebarRow(
                    depth: 1,
                    icon: .none,
                    label: isLoading ? "Loading…" : "No snapshots",
                    labelColor: ColorTokens.Text.tertiary,
                    labelFont: TypographyTokens.detail
                )
            }
            ForEach(snapshots) { snapshot in
                Button {
                    // Select snapshot
                } label: {
                    SidebarRow(
                        depth: 1,
                        icon: .system("camera.fill"),
                        label: snapshot.name,
                        iconColor: ExplorerSidebarPalette.folderIconColor(title: "Database Snapshots", colored: colored)
                    ) {
                        Text(snapshot.sourceDatabaseName)
                            .font(SidebarRowConstants.trailingFont)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    snapshotContextMenu(snapshot: snapshot, session: session)
                }
            }
        }
    }

    // MARK: - Snapshot Context Menu

    @ViewBuilder
    private func snapshotContextMenu(snapshot: SQLServerDatabaseSnapshot, session: ConnectionSession) -> some View {
        Button {
            Task {
                let handle = AppDirector.shared.activityEngine.begin(
                    "Revert \(snapshot.sourceDatabaseName) to snapshot \(snapshot.name)",
                    connectionSessionID: session.id
                )
                do {
                    try await session.session.revertToSnapshot(snapshotName: snapshot.name)
                    handle.succeed()
                    environmentState.notificationEngine?.post(
                        category: .maintenanceCompleted,
                        message: "Reverted \(snapshot.sourceDatabaseName) to snapshot \(snapshot.name)."
                    )
                } catch {
                    handle.fail(error.localizedDescription)
                    environmentState.notificationEngine?.post(
                        category: .maintenanceFailed,
                        message: "Revert failed: \(error.localizedDescription)"
                    )
                }
            }
        } label: {
            Label("Revert to Snapshot", systemImage: "arrow.uturn.backward")
        }

        Divider()

        Button(role: .destructive) {
            Task {
                let handle = AppDirector.shared.activityEngine.begin(
                    "Delete snapshot \(snapshot.name)",
                    connectionSessionID: session.id
                )
                do {
                    try await session.session.deleteDatabaseSnapshot(name: snapshot.name)
                    handle.succeed()
                    environmentState.notificationEngine?.post(
                        category: .maintenanceCompleted,
                        message: "Snapshot \(snapshot.name) deleted."
                    )
                    loadDatabaseSnapshots(session: session)
                } catch {
                    handle.fail(error.localizedDescription)
                    environmentState.notificationEngine?.post(
                        category: .maintenanceFailed,
                        message: "Delete snapshot failed: \(error.localizedDescription)"
                    )
                }
            }
        } label: {
            Label("Delete Snapshot", systemImage: "trash")
        }
    }

    // MARK: - Load Snapshots

    func loadDatabaseSnapshots(session: ConnectionSession) {
        let connID = session.connection.id
        viewModel.databaseSnapshotsLoadingBySession[connID] = true
        Task {
            do {
                let snapshots = try await session.session.listDatabaseSnapshots()
                viewModel.databaseSnapshotsBySession[connID] = snapshots
            } catch {
                viewModel.databaseSnapshotsBySession[connID] = []
            }
            viewModel.databaseSnapshotsLoadingBySession[connID] = false
        }
    }
}
