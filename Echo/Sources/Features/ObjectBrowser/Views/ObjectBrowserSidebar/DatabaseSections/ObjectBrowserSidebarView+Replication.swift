import SwiftUI
import PostgresKit

extension ObjectBrowserSidebarView {

    @ViewBuilder
    func postgresReplicationSection(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful

        // Publications
        let pubExpanded = viewModel.replicationPublicationsExpandedBinding(for: connID, database: database.name)
        let pubCount = viewModel.replicationPublicationCount(connectionID: connID, database: database.name)

        folderHeaderRow(
            title: "Publications",
            icon: "arrow.up.doc",
            count: pubCount,
            isExpanded: pubExpanded,
            depth: 2
        )
        .contextMenu {
            Button {
                Task { await loadPublications(session: session, database: database.name) }
            } label: { Label("Refresh", systemImage: "arrow.clockwise") }

            Button { openNewPublicationEditor(session: session) } label: {
                Label("New Publication", systemImage: "arrow.up.doc")
            }
        }
        .onChange(of: pubExpanded.wrappedValue) { _, expanded in
            if expanded && pubCount == nil {
                Task { await loadPublications(session: session, database: database.name) }
            }
        }

        if pubExpanded.wrappedValue {
            let publications = viewModel.replicationPublications(connectionID: connID, database: database.name)
            if publications.isEmpty && pubCount != nil {
                SidebarRow(depth: 3, icon: .none, label: "No publications", labelColor: ColorTokens.Text.tertiary, labelFont: TypographyTokens.detail)
            } else if publications.isEmpty {
                SidebarRow(depth: 3, icon: .none, label: "Loading\u{2026}", labelColor: ColorTokens.Text.tertiary, labelFont: TypographyTokens.detail)
            } else {
                ForEach(publications, id: \.name) { pub in
                    publicationRow(pub: pub, session: session, connID: connID, colored: colored)
                }
            }
        }

        // Subscriptions
        let subExpanded = viewModel.replicationSubscriptionsExpandedBinding(for: connID, database: database.name)
        let subCount = viewModel.replicationSubscriptionCount(connectionID: connID, database: database.name)

        folderHeaderRow(
            title: "Subscriptions",
            icon: "arrow.down.doc",
            count: subCount,
            isExpanded: subExpanded,
            depth: 2
        )
        .contextMenu {
            Button {
                Task { await loadSubscriptions(session: session, database: database.name) }
            } label: { Label("Refresh", systemImage: "arrow.clockwise") }

            Button { openNewSubscriptionEditor(session: session) } label: {
                Label("New Subscription", systemImage: "arrow.down.doc")
            }
        }
        .onChange(of: subExpanded.wrappedValue) { _, expanded in
            if expanded && subCount == nil {
                Task { await loadSubscriptions(session: session, database: database.name) }
            }
        }

        if subExpanded.wrappedValue {
            let subscriptions = viewModel.replicationSubscriptions(connectionID: connID, database: database.name)
            if subscriptions.isEmpty && subCount != nil {
                SidebarRow(depth: 3, icon: .none, label: "No subscriptions", labelColor: ColorTokens.Text.tertiary, labelFont: TypographyTokens.detail)
            } else if subscriptions.isEmpty {
                SidebarRow(depth: 3, icon: .none, label: "Loading\u{2026}", labelColor: ColorTokens.Text.tertiary, labelFont: TypographyTokens.detail)
            } else {
                ForEach(subscriptions, id: \.name) { sub in
                    subscriptionRow(sub: sub, session: session, connID: connID, colored: colored)
                }
            }
        }
    }

    // MARK: - Row Views

    @ViewBuilder
    private func publicationRow(pub: PostgresPublicationInfo, session: ConnectionSession, connID: UUID, colored: Bool) -> some View {
        Button {
            openPublicationEditor(session: session, name: pub.name)
        } label: {
            SidebarRow(
                depth: 3,
                icon: .system("arrow.up.doc"),
                label: pub.name,
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Publications", colored: colored)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { openPublicationEditor(session: session, name: pub.name) } label: {
                Label("Edit Publication", systemImage: "pencil")
            }
            Divider()
            Menu("Script as", systemImage: "scroll") {
                Button {
                    environmentState.openScriptTab(sql: "CREATE PUBLICATION \(ScriptingActions.pgQuote(pub.name)) FOR ALL TABLES;", connectionID: connID)
                } label: { Label("CREATE", systemImage: "plus.square") }
                Button {
                    environmentState.openScriptTab(sql: "DROP PUBLICATION IF EXISTS \(ScriptingActions.pgQuote(pub.name));", connectionID: connID)
                } label: { Label("DROP", systemImage: "minus.square") }
            }
            Divider()
            Button(role: .destructive) {
                sheetState.pendingDropPublicationName = pub.name
                sheetState.pendingDropPublicationConnID = connID
            } label: { Label("Drop Publication", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private func subscriptionRow(sub: PostgresSubscriptionInfo, session: ConnectionSession, connID: UUID, colored: Bool) -> some View {
        Button {
            openSubscriptionEditor(session: session, name: sub.name)
        } label: {
            SidebarRow(
                depth: 3,
                icon: .system("arrow.down.doc"),
                label: sub.name,
                subtitle: sub.enabled ? nil : "Disabled",
                iconColor: ExplorerSidebarPalette.folderIconColor(title: "Subscriptions", colored: colored)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { openSubscriptionEditor(session: session, name: sub.name) } label: {
                Label("Edit Subscription", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                sheetState.pendingDropSubscriptionName = sub.name
                sheetState.pendingDropSubscriptionConnID = connID
            } label: { Label("Drop Subscription", systemImage: "trash") }
        }
    }

    // MARK: - Editor Actions

    private func openNewPublicationEditor(session: ConnectionSession) {
        let value = environmentState.preparePublicationEditorWindow(
            connectionSessionID: session.connection.id, existingPublication: nil
        )
        openWindow(id: PublicationEditorWindow.sceneID, value: value)
    }

    private func openPublicationEditor(session: ConnectionSession, name: String) {
        let value = environmentState.preparePublicationEditorWindow(
            connectionSessionID: session.connection.id, existingPublication: name
        )
        openWindow(id: PublicationEditorWindow.sceneID, value: value)
    }

    private func openNewSubscriptionEditor(session: ConnectionSession) {
        let value = environmentState.prepareSubscriptionEditorWindow(
            connectionSessionID: session.connection.id, existingSubscription: nil
        )
        openWindow(id: SubscriptionEditorWindow.sceneID, value: value)
    }

    private func openSubscriptionEditor(session: ConnectionSession, name: String) {
        let value = environmentState.prepareSubscriptionEditorWindow(
            connectionSessionID: session.connection.id, existingSubscription: name
        )
        openWindow(id: SubscriptionEditorWindow.sceneID, value: value)
    }

    // MARK: - Data Loading

    func loadPublicationsIfNeeded(session: ConnectionSession, database: String) async {
        let connID = session.connection.id
        guard viewModel.replicationPublicationCount(connectionID: connID, database: database) == nil else { return }
        await loadPublications(session: session, database: database)
    }

    func loadSubscriptionsIfNeeded(session: ConnectionSession, database: String) async {
        let connID = session.connection.id
        guard viewModel.replicationSubscriptionCount(connectionID: connID, database: database) == nil else { return }
        await loadSubscriptions(session: session, database: database)
    }

    private func loadPublications(session: ConnectionSession, database: String) async {
        guard let pg = session.session as? PostgresSession else { return }
        let handle = AppDirector.shared.activityEngine.begin("Loading publications", connectionSessionID: session.id)
        do {
            let pubs = try await pg.client.metadata.listPublications()
            viewModel.setReplicationPublications(pubs, connectionID: session.connection.id, database: database)
            handle.succeed()
        } catch {
            handle.fail(error.localizedDescription)
        }
    }

    private func loadSubscriptions(session: ConnectionSession, database: String) async {
        guard let pg = session.session as? PostgresSession else { return }
        let handle = AppDirector.shared.activityEngine.begin("Loading subscriptions", connectionSessionID: session.id)
        do {
            let subs = try await pg.client.metadata.listSubscriptions()
            viewModel.setReplicationSubscriptions(subs, connectionID: session.connection.id, database: database)
            handle.succeed()
        } catch {
            handle.fail(error.localizedDescription)
        }
    }
}
