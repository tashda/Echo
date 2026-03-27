import SwiftUI

/// Database Explorer — hierarchical object list rendered inside a sidebar `List`.
struct DatabaseObjectBrowserView: View {
    let database: DatabaseInfo
    let connection: SavedConnection
    @Binding var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType>
    @Binding var expandedObjectIDs: Set<String>
    @Binding var pinnedObjectIDs: Set<String>
    @Binding var isPinnedSectionExpanded: Bool
    let scrollTo: (String, UnitPoint) -> Void
    var onNewExtension: (() -> Void)? = nil

    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(EnvironmentState.self) var environmentState
    @Environment(ObjectBrowserSidebarViewModel.self) var viewModel

    @State private var snapshotData: SnapshotData = .empty
    @State internal var showNewSequenceSheet = false
    @State internal var showNewTriggerSheet = false

    private var supportedObjectTypes: [SchemaObjectInfo.ObjectType] {
        SchemaObjectInfo.ObjectType.supported(for: connection.databaseType)
    }

    func displayName(for object: SchemaObjectInfo) -> String {
        object.fullName
    }

    func shouldShowColumns(for object: SchemaObjectInfo) -> Bool {
        object.type == .table || object.type == .view || object.type == .materializedView
    }

    func togglePin(for object: SchemaObjectInfo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if pinnedObjectIDs.contains(object.id) {
                pinnedObjectIDs.remove(object.id)
            } else {
                pinnedObjectIDs.insert(object.id)
                isPinnedSectionExpanded = true
            }
        }
    }

    func expansionBinding(for objectID: String) -> Binding<Bool> {
        Binding(
            get: { expandedObjectIDs.contains(objectID) },
            set: { newValue in
                if newValue { expandedObjectIDs.insert(objectID) }
                else { expandedObjectIDs.remove(objectID) }
            }
        )
    }

    func typeExpandedBinding(for type: SchemaObjectInfo.ObjectType) -> Binding<Bool> {
        Binding(
            get: { expandedObjectGroups.contains(type) },
            set: { newValue in
                if newValue { expandedObjectGroups.insert(type) }
                else { expandedObjectGroups.remove(type) }
            }
        )
    }

    func revealTable(fullName: String) {
        guard let target = database.schemas
            .flatMap({ $0.objects.filter { $0.type == .table } })
            .first(where: { $0.fullName == fullName }) else { return }

        expandedObjectGroups.insert(.table)
        expandedObjectIDs.insert(target.id)

        Task {
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollTo(target.id, UnitPoint(x: 0.5, y: 0.2))
            }
        }
    }

    private var snapshotIdentity: SnapshotIdentity {
        let totalObjects = database.schemas.reduce(0) { $0 + $1.objects.count }
        return SnapshotIdentity(
            databaseName: database.name,
            schemaCount: database.schemas.count,
            objectCount: totalObjects,
            extensionCount: database.extensions.count,
            pinnedIDs: pinnedObjectIDs,
            supportedTypes: supportedObjectTypes
        )
    }

    var body: some View {
        let snapshot = snapshotData

        Group {
            if !snapshot.pinned.isEmpty {
                pinnedSection(snapshot.pinned)
            }

            ForEach(supportedObjectTypes, id: \.self) { type in
                typeSection(type, snapshot.grouped[type] ?? [])
            }
        }
        .task(id: snapshotIdentity) {
            let db = database
            let pins = pinnedObjectIDs
            let types = supportedObjectTypes
            let newData = await SnapshotBuilder.buildData(from: db, pinnedIDs: pins, supportedTypes: types)
            if newData != snapshotData {
                snapshotData = newData
            }
        }
        .sheet(isPresented: $showNewSequenceSheet) {
            if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
                let schema = database.schemas.first?.name ?? "public"
                NewSequenceSheet(session: session, schemaName: schema) {
                    showNewSequenceSheet = false
                    reloadSchema()
                }
            }
        }
        .sheet(isPresented: $showNewTriggerSheet) {
            if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
                let schema = database.schemas.first?.name ?? "public"
                NewTriggerSheet(session: session, schemaName: schema) {
                    showNewTriggerSheet = false
                    reloadSchema()
                }
            }
        }
    }

    private func reloadSchema() {
        if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
            Task {
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
            }
        }
    }
}
