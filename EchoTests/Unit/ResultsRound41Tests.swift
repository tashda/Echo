import Foundation
import Testing
@testable import Echo

@Suite("Results round 41: error chips, timeline, run history, message groups")
struct ResultsRound41Tests {
    private func error(number: String = "248", level: String = "16", state: String = "1") -> QueryExecutionMessage {
        QueryExecutionMessage(index: 1, message: "overflowed", severity: .error,
                              metadata: ["messageNumber": number, "level": level, "state": state])
    }

    @Test func errorChipsAreSQLServersNumbers() {
        #expect(error().errorChips == ["Msg 248", "Level 16", "State 1"])
        #expect(QueryExecutionMessage(index: 1, message: "hi", severity: .info).errorChips.isEmpty)
        let messages = [error(number: "1"), QueryExecutionMessage(index: 2, message: "after", severity: .info), error(number: "2")]
        #expect(QueryExecutionMessage.errorChips(in: messages).first == "Msg 2")
    }

    @Test func timelineSplitsTheRunIntoItsPhases() throws {
        var timings = QueryPerformanceTracker.Report.Timings()
        timings.startToDispatch = 0.1
        timings.startToFirstUpdate = 0.8
        timings.startToFinish = 1.3
        let timeline = try #require(QueryRunTimeline(timings: timings))
        #expect(abs(timeline.sending - 0.1) < 0.0001)
        #expect(abs(timeline.waiting - 0.7) < 0.0001)
        #expect(abs(timeline.reading - 0.5) < 0.0001)
        #expect(abs(timeline.total - 1.3) < 0.0001)
    }

    @Test func timelineWithoutRowsIsAllWaiting() throws {
        var timings = QueryPerformanceTracker.Report.Timings()
        timings.startToDispatch = 0.05
        timings.startToFinish = 0.5
        let timeline = try #require(QueryRunTimeline(timings: timings))
        #expect(timeline.reading == 0)
        #expect(abs(timeline.waiting - 0.45) < 0.0001)
        #expect(QueryRunTimeline(timings: .init()) == nil)
    }

    @Test func runHistoryKeepsTheNewestFive() {
        let start = Date(timeIntervalSince1970: 0)
        var history: [QueryRunRecord] = []
        for second in 1...7 {
            history = QueryRunRecord.appending(QueryRunRecord(startedAt: start, finishedAt: start.addingTimeInterval(Double(second)), outcome: .succeeded), to: history)
        }
        #expect(history.map(\.duration) == [3, 4, 5, 6, 7])
    }

    @Test func statementHeadingIsTheFirstLineWithText() {
        let sql = "-- a\n\n  select *\nfrom t\n\nupdate t set a = 1"
        let whole = QueryMessageStatement.heading(for: sql)
        #expect(whole == QueryMessageStatement(line: 1, text: "-- a"))
        let range = (sql as NSString).range(of: "\n  select *\nfrom t")
        #expect(QueryMessageStatement.heading(for: sql, range: range) == QueryMessageStatement(line: 3, text: "select *"))
        let update = (sql as NSString).range(of: "update t set a = 1")
        #expect(QueryMessageStatement.heading(for: sql, range: update)?.line == 6)
        #expect(QueryMessageStatement.heading(for: sql, range: NSRange(location: 4, length: 2)) == nil)
    }

    @Test func messagesGroupByConsecutiveStatement() {
        let first = QueryMessageStatement(line: 1, text: "select 1")
        let second = QueryMessageStatement(line: 2, text: "select 2")
        let messages = [
            QueryExecutionMessage(index: 1, message: "a", statement: first),
            QueryExecutionMessage(index: 2, message: "b", statement: first),
            QueryExecutionMessage(index: 3, message: "c", statement: second),
            QueryExecutionMessage(index: 4, message: "d"),
        ]
        let groups = QueryMessageGroup.groups(from: messages)
        #expect(groups.map(\.statement) == [first, second, nil])
        #expect(groups.map(\.messages.count) == [2, 1, 1])
    }
}

@Suite("Results round 41: what the server returned")
struct ServerMessageFieldsTests {
    @Test func sqlServerFieldsComeInOrderThenTheRest() {
        let message = QueryExecutionMessage(
            index: 1, category: "Server Response", message: "overflowed", severity: .error, procedure: "dbo.load", line: 7,
            metadata: ["messageNumber": "248", "level": "16", "state": "1", "server": "dwh", "sqlstate": "22003"])
        #expect(message.isFromServer)
        #expect(message.serverFields.map { $0.label } == ["Message number", "Level", "State", "Line", "Procedure", "Server", "sqlstate"])
        #expect(message.serverCopyText.hasSuffix("\noverflowed"))
    }

    @Test func echosOwnLinesAreNotFromTheServer() {
        #expect(!QueryExecutionMessage(index: 1, category: "Connection", message: "reconnected").isFromServer)
        #expect(QueryExecutionMessage(index: 1, category: "Server Response", message: "hi").isFromServer)
    }
}

@Suite("Results round 41: the selection pill's Setting")
struct SelectionPillFiguresTests {
    @Test func eachChoiceSaysWhichFiguresItAdds() {
        #expect(!SelectionPillFigures.count.showsSum && !SelectionPillFigures.count.showsAverage)
        #expect(SelectionPillFigures.countAndSum.showsSum && !SelectionPillFigures.countAndSum.showsAverage)
        #expect(!SelectionPillFigures.countAndAverage.showsSum && SelectionPillFigures.countAndAverage.showsAverage)
        #expect(SelectionPillFigures.countSumAndAverage.showsSum && SelectionPillFigures.countSumAndAverage.showsAverage)
    }

    @Test func theDefaultIsOnlyTheCount() {
        #expect(GlobalSettings().resultsSelectionPill == .count)
    }
}
