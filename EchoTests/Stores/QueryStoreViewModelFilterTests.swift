import Testing
import Foundation
@testable import Echo

@Suite("QueryStoreViewModel Filtering")
struct QueryStoreViewModelFilterTests {

    @Test("TimeRange has all expected cases")
    func timeRangeCases() {
        let allCases = QueryStoreViewModel.TimeRange.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.lastHour))
        #expect(allCases.contains(.lastDay))
        #expect(allCases.contains(.lastWeek))
        #expect(allCases.contains(.allTime))
    }

    @Test("TimeRange raw values match display text")
    func timeRangeRawValues() {
        #expect(QueryStoreViewModel.TimeRange.lastHour.rawValue == "Last Hour")
        #expect(QueryStoreViewModel.TimeRange.lastDay.rawValue == "Last 24 Hours")
        #expect(QueryStoreViewModel.TimeRange.lastWeek.rawValue == "Last 7 Days")
        #expect(QueryStoreViewModel.TimeRange.allTime.rawValue == "All Time")
    }

    @Test("allTime startDate returns nil")
    func allTimeStartDate() {
        #expect(QueryStoreViewModel.TimeRange.allTime.startDate == nil)
    }

    @Test("lastHour startDate returns approximately 1 hour ago")
    func lastHourStartDate() {
        let date = QueryStoreViewModel.TimeRange.lastHour.startDate
        #expect(date != nil)
        if let date {
            let diff = Date().timeIntervalSince(date)
            #expect(diff >= 3590 && diff <= 3610)
        }
    }

    @Test("lastDay startDate returns approximately 24 hours ago")
    func lastDayStartDate() {
        let date = QueryStoreViewModel.TimeRange.lastDay.startDate
        #expect(date != nil)
        if let date {
            let diff = Date().timeIntervalSince(date)
            #expect(diff >= 86390 && diff <= 86410)
        }
    }

    @Test("lastWeek startDate returns approximately 7 days ago")
    func lastWeekStartDate() {
        let date = QueryStoreViewModel.TimeRange.lastWeek.startDate
        #expect(date != nil)
        if let date {
            let diff = Date().timeIntervalSince(date)
            #expect(diff >= 604790 && diff <= 604810)
        }
    }

    @Test("SelectedSection has expected cases")
    func selectedSectionCases() {
        let allCases = QueryStoreViewModel.SelectedSection.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.topQueries))
        #expect(allCases.contains(.regressedQueries))
    }
}
