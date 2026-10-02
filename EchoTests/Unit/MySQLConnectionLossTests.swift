import EchoSense
import Foundation
import Logging
import MySQLKit
import Synchronization
import Testing
@testable import Echo

/// A MySQL tab after its connection dropped with a transaction open (rounds 21 and 22): runs say to
/// Reconnect and bring the notification back; other errors keep the server's words.
@Suite("MySQL connection loss")
struct MySQLConnectionLossTests {
    private func session() -> MySQLSession {
        // Never connects: the client opens its connection on first use.
        let configuration = MySQLConfiguration(host: "127.0.0.1", username: "u", database: "shop", tlsMode: .disabled)
        return MySQLSession(
            client: MySQLClient(configuration: configuration),
            configuration: configuration,
            logger: Logger(label: "test"),
            defaultDatabase: "shop"
        )
    }

    @Test func aRunWhileWaitingForReconnectSaysSoAndReminds() async throws {
        let session = session()
        let calls = Mutex<[(String, Bool, Bool)]>([])
        session.setConnectionLostHandler { database, lost, reminder in calls.withLock { $0.append((database, lost, reminder)) } }
        let failure = await session.queryFailure(MySQLWireError.transactionLost)
        #expect(failure as? MySQLSessionError == .awaitingReconnect(database: "shop"))
        #expect(failure.localizedDescription == QueryConnectionLossText.awaitingReconnect(database: "shop"))
        let recorded = calls.withLock { $0 }
        #expect(recorded.count == 1)
        #expect(recorded.first.map { $0.0 == "shop" && $0.1 && $0.2 } == true)
    }

    @Test func otherErrorsKeepTheServersWords() async throws {
        let session = session()
        let failure = await session.queryFailure(MySQLWireError.missingDatabaseName)
        #expect(failure.localizedDescription.hasSuffix(MySQLWireError.missingDatabaseName.localizedDescription))
    }

    @Test func noConnectionMeansNoTransactionAndNoLoss() async throws {
        let session = session()
        let called = Mutex(false)
        session.setConnectionLostHandler { _, _, _ in called.withLock { $0 = true } }
        #expect(await !session.isInTransaction)
        await session.checkConnection()
        #expect(!called.withLock { $0 })
        let stop = await session.forceStopRunningQuery()
        #expect(!stop.stopped && !stop.transactionWasOpen)
    }
}
