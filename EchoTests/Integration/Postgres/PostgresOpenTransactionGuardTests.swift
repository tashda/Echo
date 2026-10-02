import Foundation
import PostgresKit
import ServerLabClient
import Testing
@testable import Echo

/// Round 21, open transaction on close (accepted): the tab's store finds its open transactions
/// (checked with the server), commits or rolls them back, and a failed one is only rolled back.
/// The transactions are SQL a user types in the editor; the tables around them are made with
/// echo-postgres's typed APIs.
@Suite(.enabled(if: labIntegrationEnabled, labIntegrationNote), .server("pg-17-empty"), .timeLimit(.minutes(10)))
@MainActor
struct PostgresOpenTransactionGuardTests {
    /// A pinned session (as a query tab has) and a fresh table only this test uses; the table and
    /// its `<table>_parent`, if the test made one, are dropped afterwards.
    private func withGuardSession(_ body: (PostgresSession, String) async throws -> Void) async throws {
        let server = try #require(LabServer.current)
        let base = try await PostgresNIOFactory().connect(
            host: server.host, port: server.port, database: "postgres", tls: false, tlsMode: .disable,
            authentication: DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password)
        )
        let session = try #require(base as? PostgresSession).withPinnedQueries()
        let table = "guard_\(UUID().uuidString.prefix(8).lowercased())"
        try await session.client.admin.createTable(name: table, columns: [PostgresColumnDefinition(name: "id", dataType: "int")])
        do {
            try await body(session, table)
        } catch {
            await cleanUp(session, tables: [table, "\(table)_parent"])
            throw error
        }
        await cleanUp(session, tables: [table, "\(table)_parent"])
    }

    private func cleanUp(_ session: PostgresSession, tables: [String]) async {
        _ = try? await run(session, "ROLLBACK")
        for table in tables {
            _ = try? await session.client.admin.dropTable(name: table, ifExists: true, cascade: true)
        }
        await session.close()
    }

    @discardableResult
    private func run(_ session: PostgresSession, _ sql: String) async throws -> QueryResultSet {
        try await session.simpleQuery(sql, executionMode: nil, progressHandler: { _ in })
    }

    private func rows(in table: String, _ session: PostgresSession) async throws -> Int64 {
        try await session.client.metadata.exactRowCount(table: table)
    }

    @Test func openTransactionsAreFoundWithTheirDetails() async throws {
        try await withGuardSession { session, table in
            let store = try #require(session.pinnedStore)
            #expect(await store.openTransactions().isEmpty)
            try await run(session, "BEGIN")
            try await run(session, "INSERT INTO \(table) VALUES (1)")
            try await run(session, "INSERT INTO \(table) VALUES (2)")
            let open = await store.openTransactions()
            #expect(open.count == 1)
            #expect(open.first?.database == "postgres")
            #expect(open.first?.statements == 2)
            #expect(open.first?.failed == false)
            #expect(open.first?.startedAt != nil)
        }
    }

    @Test func commitKeepsTheWork() async throws {
        try await withGuardSession { session, table in
            let store = try #require(session.pinnedStore)
            try await run(session, "BEGIN")
            try await run(session, "INSERT INTO \(table) VALUES (1)")
            try await store.endTransactions(commit: true)
            #expect(try await rows(in: table, session) == 1)
            #expect(await store.openTransactions().isEmpty)
        }
    }

    @Test func rollBackDiscardsTheWork() async throws {
        try await withGuardSession { session, table in
            let store = try #require(session.pinnedStore)
            try await run(session, "BEGIN")
            try await run(session, "INSERT INTO \(table) VALUES (1)")
            try await store.endTransactions(commit: false)
            #expect(try await rows(in: table, session) == 0)
        }
    }

    @Test func aFailedTransactionIsRolledBackEvenWhenCommitIsAsked() async throws {
        try await withGuardSession { session, table in
            let store = try #require(session.pinnedStore)
            try await run(session, "BEGIN")
            try await run(session, "INSERT INTO \(table) VALUES (1)")
            await #expect(throws: (any Error).self) { try await run(session, "SELECT 1/0") }
            #expect(await store.openTransactions().first?.failed == true)
            try await store.endTransactions(commit: true)
            #expect(try await rows(in: table, session) == 0)
            #expect(await store.openTransactions().isEmpty)
        }
    }

    @Test func aCommitTheServerRefusesIsReported() async throws {
        try await withGuardSession { session, table in
            let store = try #require(session.pinnedStore)
            let parent = "\(table)_parent"
            try await session.client.admin.createTable(name: parent, columns: [PostgresColumnDefinition(name: "id", dataType: "int", primaryKey: true)])
            try await session.client.constraints.addCompositeForeignKey(table: table, columns: ["id"], referencesTable: parent,
                                                                        referencesColumns: ["id"], deferrable: true, initiallyDeferred: true)
            try await run(session, "BEGIN")
            try await run(session, "INSERT INTO \(table) VALUES (42)")   // checked at COMMIT
            await #expect(throws: (any Error).self, "the deferred foreign key fails at COMMIT") {
                try await store.endTransactions(commit: true)
            }
        }
    }
}
