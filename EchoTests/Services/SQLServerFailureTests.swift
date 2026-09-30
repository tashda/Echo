import Foundation
import SQLServerKit
import Testing
@testable import Echo

@Suite("SQL Server failures (round 22, errors)")
struct SQLServerFailureTests {
    private static func message(
        _ kind: SQLServerStreamMessage.Kind, _ number: Int32, _ text: String,
        severity: UInt8, line: Int32 = 1, procedure: String = ""
    ) -> SQLServerStreamMessage {
        SQLServerStreamMessage(kind: kind, number: number, message: text, state: 1, severity: severity,
                               serverName: "sql01", procedureName: procedure, lineNumber: line)
    }

    private static let batch = [
        message(.info, 0, "loading orders", severity: 0),
        message(.error, 208, "Invalid object name 'dbo.nope'.", severity: 16, line: 3),
    ]

    @Test func everyMessageOfTheBatchSurvivesTheWrapping() throws {
        let failure = try #require(SQLServerError.fromServerMessages(Self.batch))
        let wrapped = DatabaseError.from(sqlServerError: failure)
        for error in [failure as any Error, wrapped as any Error] {
            let messages = SQLServerFailure.serverMessages(of: error)
            #expect(messages.map(\.message) == ["loading orders", "Invalid object name 'dbo.nope'."])
            #expect(messages.map(\.kind) == [.info, .error])
            #expect(SQLServerFailure.details(of: error)?.lineNumber == 3)
            #expect(SQLServerFailure.details(of: error)?.number == 208)
        }
        // The text users see is unchanged by carrying the details.
        #expect(wrapped.localizedDescription == DatabaseError.queryError("Invalid object name 'dbo.nope'.").localizedDescription)
    }

    @Test func otherErrorsHaveNoServerMessages() {
        #expect(SQLServerFailure.serverMessages(of: DatabaseError.queryError("x")).isEmpty)
        #expect(SQLServerFailure.serverMessages(of: CancellationError()).isEmpty)
        #expect(!SQLServerFailure.isConnectionLost(DatabaseError.queryError("x")))
    }

    @Test func headersReadLikeSSMS() {
        let plain = Self.message(.error, 208, "Invalid object name 'x'.", severity: 16, line: 3).echoServerMessage
        #expect(plain.ssmsHeader == "Msg 208, Level 16, State 1, Line 3")
        let inProcedure = Self.message(.error, 50000, "boom", severity: 16, line: 12, procedure: "dbo.load_orders").echoServerMessage
        #expect(inProcedure.ssmsHeader == "Msg 50000, Level 16, State 1, Procedure dbo.load_orders, Line 12")
        #expect(Self.message(.info, 0, "loading orders", severity: 0).echoServerMessage.ssmsHeader == nil)
        #expect(Self.message(.info, 5701, "Changed database context to 'master'.", severity: 10).echoServerMessage.ssmsHeader == nil)
    }

    @Test func severityTwentyTakesTheLostConnectionPath() throws {
        let fatal = try #require(SQLServerError.fromServerMessages([Self.message(.error, 50000, "fatal", severity: 20)]))
        #expect(SQLServerFailure.isConnectionLost(fatal))
        #expect(SQLServerFailure.isConnectionLost(DatabaseError.from(sqlServerError: fatal)))
        let ordinary = try #require(SQLServerError.fromServerMessages(Self.batch))
        #expect(!SQLServerFailure.isConnectionLost(ordinary))
        #expect(SQLServerFailure.isConnectionLost(SQLServerError.connectionClosed))
    }
}
