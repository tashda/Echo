import Foundation
import Testing
@testable import Echo

/// The tree is rebuilt, node by node, for every structure update; a row is drawn again only when
/// its render key changes.
@MainActor
@Suite("Explorer row render keys")
struct ExplorerRenderKeyTests {
    private let session: ConnectionSession = {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RenderKeyTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ConnectionSession(
            connection: TestFixtures.savedConnection(connectionName: "Keys"),
            session: MockDatabaseSession(),
            spoolManager: ResultSpooler(configuration: .defaultConfiguration(rootDirectory: root))
        )
    }()

    private func databaseNode(_ info: DatabaseInfo, id: String = "db", children: [ObjectBrowserNode] = [ObjectBrowserNode(id: "db#loading", row: .loading("Loading objects", style: .skeleton))]) -> ObjectBrowserNode {
        ObjectBrowserNode(id: id, row: .database(session, info), children: children)
    }

    private func folderNode(count: Int?, isLoading: Bool = false) -> ObjectBrowserNode {
        ObjectBrowserNode(id: "f", row: .folder(ExplorerFolder(kind: .tables, session: session, databaseName: "db", count: count, isLoading: isLoading, source: nil)))
    }

    private func objectNode(_ object: SchemaObjectInfo, children: [ObjectBrowserNode] = []) -> ObjectBrowserNode {
        ObjectBrowserNode(id: "o", row: .object(session, "db", object), children: children)
    }

    @Test func aRebuiltRowWithTheSameContentHasTheSameKey() {
        #expect(databaseNode(DatabaseInfo(name: "db")).renderKey == databaseNode(DatabaseInfo(name: "db")).renderKey)
        #expect(folderNode(count: 3).renderKey == folderNode(count: 3).renderKey)
        let object = SchemaObjectInfo(name: "t", schema: "dbo", type: .table, columns: [ColumnInfo(name: "id", dataType: "int")])
        #expect(objectNode(object).renderKey == objectNode(object).renderKey)
        let placeholder: () -> ObjectBrowserNode = { ObjectBrowserNode(id: "p", row: .placeholder("No views", kind: nil)) }
        #expect(placeholder().renderKey == placeholder().renderKey)
        let loading: () -> ObjectBrowserNode = { ObjectBrowserNode(id: "l", row: .loading("Loading", style: .spinnerRow)) }
        #expect(loading().renderKey == loading().renderKey)
        let message: () -> ObjectBrowserNode = { ObjectBrowserNode(id: "m", row: .message("Failed", systemImage: "x")) }
        #expect(message().renderKey == message().renderKey)
        let spacer: () -> ObjectBrowserNode = { ObjectBrowserNode(id: "s", row: .topSpacer(4)) }
        #expect(spacer().renderKey == spacer().renderKey)
        let action: () -> ObjectBrowserNode = { ObjectBrowserNode(id: "a", row: .action(self.session, .maintenance, databaseName: nil)) }
        #expect(action().renderKey == action().renderKey)
    }

    @Test func aDatabaseRowDoesNotChangeBecauseItsSchemasArrived() {
        let listed = DatabaseInfo(name: "db")
        let loaded = DatabaseInfo(name: "db", schemas: [SchemaInfo(name: "dbo", objects: [SchemaObjectInfo(name: "t", schema: "dbo", type: .table)])])
        #expect(databaseNode(listed).renderKey == databaseNode(loaded).renderKey)
    }

    @Test func aDatabaseRowChangesWithWhatItDraws() {
        let online = databaseNode(DatabaseInfo(name: "db")).renderKey
        #expect(online != databaseNode(DatabaseInfo(name: "db", stateDescription: "OFFLINE")).renderKey)
        #expect(online != databaseNode(DatabaseInfo(name: "db", hasAccess: false)).renderKey)
        #expect(online != databaseNode(DatabaseInfo(name: "other")).renderKey)
        #expect(online != databaseNode(DatabaseInfo(name: "db"), id: "db2").renderKey)
        // Activating it opens or closes it only when it has something to open.
        #expect(online != databaseNode(DatabaseInfo(name: "db"), children: []).renderKey)
    }

    @Test func aFolderChangesWithItsCountAndLoading() {
        #expect(folderNode(count: 3).renderKey != folderNode(count: 4).renderKey)
        #expect(folderNode(count: nil).renderKey != folderNode(count: 4).renderKey)
        #expect(folderNode(count: 3).renderKey != folderNode(count: 3, isLoading: true).renderKey)
    }

    @Test func anObjectChangesWithItsContent() {
        let plain = SchemaObjectInfo(name: "t", schema: "dbo", type: .table)
        let withColumn = SchemaObjectInfo(name: "t", schema: "dbo", type: .table, columns: [ColumnInfo(name: "id", dataType: "int")])
        #expect(objectNode(plain).renderKey != objectNode(withColumn).renderKey)
        #expect(objectNode(plain).renderKey != objectNode(SchemaObjectInfo(name: "t", schema: "dbo", type: .view)).renderKey)
        let column = ObjectBrowserNode(id: "c", row: .column(ColumnInfo(name: "id", dataType: "int"), ExplorerColumnOwner(session: session, databaseName: "db", object: plain)))
        let wider = ObjectBrowserNode(id: "c", row: .column(ColumnInfo(name: "id", dataType: "bigint"), ExplorerColumnOwner(session: session, databaseName: "db", object: plain)))
        #expect(column.renderKey != wider.renderKey)
    }

    @Test func anItemChangesWithWhatItShows() {
        func node(_ item: ExplorerItem) -> ObjectBrowserNode {
            ObjectBrowserNode(id: "i", row: .item(ExplorerItemRow(kind: .login, session: session, databaseName: nil, item: item)))
        }
        let login = ExplorerItem(id: "sa", name: "sa", detail: "SQL", isDisabled: false)
        #expect(node(login).renderKey == node(ExplorerItem(id: "sa", name: "sa", detail: "SQL", isDisabled: false)).renderKey)
        #expect(node(login).renderKey != node(ExplorerItem(id: "sa", name: "sa", detail: "SQL", isDisabled: true)).renderKey)
        #expect(node(login).renderKey != node(ExplorerItem(id: "sa", name: "sa", detail: "Windows", isDisabled: false)).renderKey)
    }

    @Test func rowsThatAreNotComparedByContentAreDrawnAgainWithEveryNode() {
        let first = ObjectBrowserNode(id: "server", row: .server(session))
        let second = ObjectBrowserNode(id: "server", row: .server(session))
        #expect(first.renderKey != second.renderKey)
        #expect(first.renderKey == first.renderKey)

        let object = SchemaObjectInfo(name: "t", schema: "dbo", type: .table)
        var renaming = ExplorerColumnOwner(session: session, databaseName: "db", object: object)
        renaming.isRenaming = true
        let column = ColumnInfo(name: "id", dataType: "int")
        let renamingFirst = ObjectBrowserNode(id: "c", row: .column(column, renaming))
        let renamingSecond = ObjectBrowserNode(id: "c", row: .column(column, renaming))
        #expect(renamingFirst.renderKey != renamingSecond.renderKey)
    }
}
