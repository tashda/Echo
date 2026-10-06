import Foundation
import Observation
import Synchronization
import Testing
@testable import Echo

/// A server's schemas arrive one database at a time and each one replaces `databaseStructure`.
/// What reads only the list, a version or one database must not be told about the others.
@MainActor
@Suite("Connection session database slices")
struct ConnectionSessionDatabaseSlicesTests {
    private func makeSession() -> ConnectionSession {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SessionSlices-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ConnectionSession(
            connection: TestFixtures.savedConnection(connectionName: "Slices"),
            session: MockDatabaseSession(),
            spoolManager: ResultSpooler(configuration: .defaultConfiguration(rootDirectory: root))
        )
    }

    private func table(_ name: String) -> SchemaObjectInfo {
        SchemaObjectInfo(name: name, schema: "dbo", type: .table, columns: [ColumnInfo(name: "id", dataType: "int")])
    }

    private func database(_ name: String, tables: [String] = [], state: String? = nil, hasAccess: Bool? = nil) -> DatabaseInfo {
        let schemas = tables.isEmpty ? [] : [SchemaInfo(name: "dbo", objects: tables.map(table))]
        return DatabaseInfo(name: name, schemas: schemas, stateDescription: state, hasAccess: hasAccess)
    }

    /// Whether `read` is told when `change` runs.
    private func isTold(by change: () -> Void, reading read: @escaping () -> Void) -> Bool {
        let told = Mutex(false)
        withObservationTracking { read() } onChange: { told.withLock { $0 = true } }
        change()
        return told.withLock { $0 }
    }

    @Test func theListIsKeptWithoutSchemas() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(serverVersion: "16.0", databases: [database("a", tables: ["t"]), database("b", state: "OFFLINE")])
        #expect(session.databaseSummaries.map(\.name) == ["a", "b"])
        #expect(session.databaseSummaries[0].isOnline)
        #expect(!session.databaseSummaries[1].isOnline)
        #expect(session.databaseSummaries[1].stateDescription == "OFFLINE")
        #expect(session.hasDatabaseStructure)
        #expect(session.reportedServerVersion == "16.0")
        session.databaseStructure = nil
        #expect(session.databaseSummaries.isEmpty)
        #expect(!session.hasDatabaseStructure)
        #expect(session.reportedServerVersion == nil)
    }

    @Test func aSchemaArrivingDoesNotTellTheReadersOfTheList() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(serverVersion: "16.0", databases: [database("a"), database("b")])
        let told = isTold(by: {
            var next = session.databaseStructure!
            next.databases[0] = self.database("a", tables: ["orders", "customers"])
            next.incrementVersion(from: next.version)
            session.databaseStructure = next
        }, reading: {
            _ = session.databaseSummaries
            _ = session.hasDatabaseStructure
            _ = session.reportedServerVersion
        })
        #expect(!told)
        #expect(session.databaseStructure?.databases[0].schemas.count == 1)
    }

    @Test func aMergeThatDropsOnlineOrTrueLeavesTheListAsItWas() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(databases: [database("a", state: "ONLINE", hasAccess: true)])
        let before = session.databaseSummaries
        let told = isTold(by: {
            session.databaseStructure = DatabaseStructure(databases: [self.database("a", tables: ["t"], state: nil, hasAccess: nil)])
        }, reading: { _ = session.databaseSummaries })
        #expect(!told)
        #expect(session.databaseSummaries == before)
    }

    @Test func aStateOrAccessChangeTellsTheReadersOfTheList() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(databases: [database("a"), database("b")])
        #expect(isTold(by: { session.databaseStructure = DatabaseStructure(databases: [self.database("a", state: "OFFLINE"), self.database("b")]) },
                       reading: { _ = session.databaseSummaries }))
        #expect(isTold(by: { session.databaseStructure = DatabaseStructure(databases: [self.database("a", state: "OFFLINE"), self.database("b", hasAccess: false)]) },
                       reading: { _ = session.databaseSummaries }))
        #expect(session.databaseSummaries.map(\.isAccessible) == [true, false])
        #expect(isTold(by: { session.databaseStructure = DatabaseStructure(databases: [self.database("b", hasAccess: false)]) },
                       reading: { _ = session.databaseSummaries }))
    }

    @Test func aServerVersionChangeTellsItsReaders() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(serverVersion: "15.0", databases: [])
        #expect(isTold(by: { session.databaseStructure = DatabaseStructure(serverVersion: "16.0", databases: []) },
                       reading: { _ = session.reportedServerVersion }))
        #expect(session.reportedServerVersion == "16.0")
    }

    @Test func aDatabaseIsToldOnlyAboutItself() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(databases: [database("a"), database("b")])
        #expect(session.databaseInfo(named: "a")?.schemas.isEmpty == true)

        let aggregate = DatabaseStructure(databases: [database("a"), database("b", tables: ["t"])])
        #expect(!isTold(by: { session.databaseStructure = aggregate }, reading: { _ = session.databaseInfo(named: "a") }))

        #expect(isTold(by: { session.databaseStructure = DatabaseStructure(databases: [self.database("a", tables: ["orders"]), self.database("b", tables: ["t"])]) },
                       reading: { _ = session.databaseInfo(named: "a") }))
        #expect(session.databaseInfo(named: "a")?.schemas.first?.objects.first?.name == "orders")
    }

    @Test func aDatabaseThatLeavesTheListHasNoInfo() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(databases: [database("a", tables: ["t"])])
        #expect(session.databaseInfo(named: "a") != nil)
        session.databaseStructure = DatabaseStructure(databases: [])
        #expect(session.databaseInfo(named: "a") == nil)
        #expect(session.databaseInfo(named: "never") == nil)
    }

    @Test func aDatabaseAskedForAfterTheStructureCameHasItsInfo() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(databases: [database("a", tables: ["t"])])
        #expect(session.databaseInfo(named: "a")?.schemas.count == 1)
    }

    @Test func theLoadingFlagIsPerDatabaseAndTellsOnlyItsReader() {
        let session = makeSession()
        let flagA = session.schemaLoadFlag(forDatabase: "a")
        #expect(!flagA.isLoading)
        #expect(!isTold(by: { _ = session.beginSchemaLoad(forDatabase: "b") }, reading: { _ = session.schemaLoadFlag(forDatabase: "a").isLoading }))
        #expect(isTold(by: { _ = session.beginSchemaLoad(forDatabase: "a") }, reading: { _ = session.schemaLoadFlag(forDatabase: "a").isLoading }))
        #expect(flagA.isLoading)
        #expect(session.isRefreshingMetadata(forDatabase: "a"))
        #expect(isTold(by: { session.finishSchemaLoad(forDatabase: "a") }, reading: { _ = session.schemaLoadFlag(forDatabase: "a").isLoading }))
        #expect(!flagA.isLoading)
        // A flag asked for while the load runs starts out loading.
        _ = session.beginSchemaLoad(forDatabase: "c")
        #expect(session.schemaLoadFlag(forDatabase: "C").isLoading)
        session.clearMetadataCacheState()
        #expect(!session.schemaLoadFlag(forDatabase: "c").isLoading)
        #expect(!session.schemaLoadFlag(forDatabase: "b").isLoading)
    }

    @Test func aSchemaIsLoadedWhenItsDatabaseIsListedAndNotListOnly() {
        let session = makeSession()
        session.databaseStructure = DatabaseStructure(databases: [database("A")])
        session.metadataFreshnessByDatabase[session.schemaLoadKey("a")] = .listOnly
        #expect(!session.hasLoadedSchema(forDatabase: "a"))
        session.markMetadataRefreshCompleted(forDatabase: "a", hasSchemas: true)
        #expect(session.hasLoadedSchema(forDatabase: "a"))
        #expect(!session.hasLoadedSchema(forDatabase: "zzz"))
    }

    @Test func aSummaryKnowsWhatItsDatabaseIs() {
        let summary = DatabaseSummary(database("x", tables: ["t"], state: "online", hasAccess: true))
        #expect(summary.isOnline && summary.isAccessible)
        #expect(summary.stateDescription == nil && summary.hasAccess == nil)
        #expect(summary.info.name == "x" && summary.info.schemas.isEmpty)
        let offline = DatabaseSummary(database("y", state: "RESTORING", hasAccess: false))
        #expect(!offline.isOnline && !offline.isAccessible)
        #expect(offline.info.stateDescription == "RESTORING" && offline.info.hasAccess == false)
    }
}
