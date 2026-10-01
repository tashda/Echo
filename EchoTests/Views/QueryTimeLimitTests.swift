import Foundation
import Testing
@testable import Echo

@Suite("Query time limits (round 21): wording, parsing, lock-wait hover")
struct QueryTimeLimitTests {
    @Test func theStopSaysWhoseLimitItWas() {
        #expect(QueryTimeLimitStop(seconds: 30, scope: .connection).explanation == "Stopped after 30 s: the statement limit for this connection.")
        #expect(QueryTimeLimitStop(seconds: 300, scope: .settings).explanation == "Stopped after 5 min: your default limit in Settings.")
        #expect(QueryTimeLimitStop(seconds: 45, scope: .server).explanation == "Stopped by the server's limit of 45 s (set for your role or database).")
        #expect(QueryTimeLimitStop(seconds: nil, scope: .server).explanation == "Stopped by a time limit set on the server.")
        #expect(QueryTimeLimitStop.format(90) == "1 min 30 s")
    }

    @Test func recognisesPostgresStatementTimeouts() {
        #expect(QueryTimeLimitStop.isStatementTimeout("ERROR: canceling statement due to statement timeout"))
        #expect(!QueryTimeLimitStop.isStatementTimeout("ERROR: canceling statement due to user request"))
    }

    @Test func parsesTheServersSetting() {
        #expect(QueryTimeLimitStop.parseServerSetting("30s") == 30)
        #expect(QueryTimeLimitStop.parseServerSetting("5min") == 300)
        #expect(QueryTimeLimitStop.parseServerSetting("250ms") == 0.25)
        #expect(QueryTimeLimitStop.parseServerSetting("1500") == 1.5)
        #expect(QueryTimeLimitStop.parseServerSetting("0") == nil)
        #expect(QueryTimeLimitStop.parseServerSetting("2h") == 7200)
    }

    @Test func theLockWaitHoverNamesTheHolder() {
        let now = Date(timeIntervalSince1970: 10_000)
        let wait = QueryLockWait(holderPID: 4412, holderUser: "anna", holderApplication: "psql",
                                 holderQuery: "UPDATE orders SET status = 'paid'", holderState: "idle in transaction",
                                 holderTransactionStartedAt: now.addingTimeInterval(-185))
        #expect(wait.summary(now: now) == "Waiting for a lock held by anna · pid 4412\npsql\nUPDATE orders SET status = 'paid'\nidle in transaction, in a transaction for 3 min")
    }
}
