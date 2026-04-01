import SwiftUI

extension ObjectBrowserSidebarView {

    // MARK: - Server Section

    @ViewBuilder
    func serverSection(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        let connID = session.connection.id
        let isExpanded = viewModel.expandedServerIDs.contains(connID)
        let isNewlyConnected = viewModel.recentlyConnectedIDs.contains(connID)

        // Emit header and content as separate children so expanding a database
        // doesn't change the height of a single monolithic child.
        // This gives the parent container per-item height tracking for stable scrollbar behavior.
        serverSectionHeader(session: session, isExpanded: isExpanded)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                StatusWaveOverlay(
                    color: ColorTokens.Status.success,
                    cornerRadius: SidebarRowConstants.hoverCornerRadius,
                    trigger: isNewlyConnected
                )
            )
            .task {
                viewModel.initializeSessionState(for: session, autoExpandSections: projectStore.globalSettings.sidebarExpandSections(for: session.connection.databaseType))
                if isNewlyConnected {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    viewModel.recentlyConnectedIDs.remove(connID)
                }
            }

        if isExpanded {
            serverContent(session: session, proxy: proxy)
        }
    }

    /// A visually rich connection header for a connected server (macOS System Settings style).
    func serverSectionHeader(session: ConnectionSession, isExpanded: Bool) -> some View {
        let expandedBinding = Binding<Bool>(
            get: { isExpanded },
            set: { _ in
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    if isExpanded {
                        viewModel.expandedServerIDs.remove(session.connection.id)
                    } else {
                        viewModel.expandedServerIDs.insert(session.connection.id)
                    }
                }
                selectedConnectionID = session.connection.id
                environmentState.sessionGroup.setActiveSession(session.id)
            }
        )

        let subtitle: String = {
            let typeName = session.connection.databaseType.displayName
            if let version = serverVersionLabel(session) {
                return "\(typeName) (\(version))"
            }
            return typeName
        }()

        return SidebarConnectionHeader(
            connectionName: serverDisplayName(session),
            subtitle: subtitle,
            databaseType: session.connection.databaseType,
            connectionColor: resolvedAccentColor(for: session.connection),
            isExpanded: expandedBinding,
            isColorful: projectStore.globalSettings.sidebarIconColorMode == .colorful,
            isSecure: session.connection.useTLS,
            connectionState: session.connectionState,
            onAction: {
                expandedBinding.wrappedValue.toggle()
            }
        )
        .contextMenu {
            serverContextMenu(session: session)
        }
    }

    // MARK: - Generic Tools (MySQL / SQLite)

    @ViewBuilder
    func genericToolsSection(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful

        Button {
            environmentState.openMaintenanceTab(connectionID: connID)
        } label: {
            SidebarRow(
                depth: 0,
                icon: .system("wrench.and.screwdriver"),
                label: "Maintenance",
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Maintenance", colored: colored)
            )
        }
        .buttonStyle(.plain)

        if session.connection.databaseType == .mysql {
            Button {
                environmentState.openServerPropertiesTab(connectionID: connID)
            } label: {
                SidebarRow(
                    depth: 0,
                    icon: .system("gearshape.2"),
                    label: "Server Properties",
                    iconColor: ExplorerSidebarPalette.folderIconColor(title: "Server Properties", colored: colored)
                )
            }
            .buttonStyle(.plain)

            Button {
                environmentState.openActivityMonitorTab(connectionID: connID)
            } label: {
                SidebarRow(
                    depth: 0,
                    icon: .system("gauge.high"),
                    label: "Activity Monitor",
                    iconColor: ExplorerSidebarPalette.folderIconColor(title: "Activity Monitor", colored: colored)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Server Content (Folder Groups)

    @ViewBuilder
    func serverContent(session: ConnectionSession, proxy: ScrollViewProxy) -> some View {
        switch session.structureLoadingState {
        case .ready, .loading:
            if let structure = session.databaseStructure, !structure.databases.isEmpty {
                databasesFolderSection(session: session, structure: structure, proxy: proxy)

                if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .postgresql {
                    securityFolderSection(session: session)
                }

                if session.connection.databaseType == .microsoftSQL {
                    databaseSnapshotsFolderSection(session: session)
                    agentJobsSection(session: session)
                    managementFolderSection(session: session)
                    ssisSection(session: session)
                    linkedServersSection(session: session)
                    serverTriggersSection(session: session)
                }

                if session.connection.databaseType == .mysql || session.connection.databaseType == .sqlite {
                    genericToolsSection(session: session)
                }
            } else if session.databaseStructure != nil {
                loadingHint()
            } else {
                loadingHint()
            }
        case .idle:
            loadingHint()
        case .failed(let message):
            failureHint(message: message, session: session)
        }
    }
}
