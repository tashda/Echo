import Testing
@testable import Echo

@MainActor
struct ActivityMonitorSectionPickerTests {
    @Test
    func mssqlSectionsUseTheExpectedNavigationOrder() {
        let labels = MSSQLActivityMonitorView.MSSQLActivitySection.allCases.map(\.rawValue)

        #expect(labels == ["Processes", "Waits", "I/O", "Queries", "XEvents", "Profiler"])
    }

    @Test
    func sixItemPickerPreservesMaintenanceItemProportions() {
        let maintenanceItemWidth = LayoutTokens.TabNavigation.pickerWidth(itemCount: 5) / 5
        let activityMonitorItemWidth = LayoutTokens.TabNavigation.pickerWidth(itemCount: 6) / 6

        #expect(activityMonitorItemWidth == maintenanceItemWidth)
    }

    @Test
    func largeActivityMonitorsUseTheNativeOverflowPolicy() {
        #expect(MSSQLActivityMonitorView.MSSQLActivitySection.allCases.count <= LayoutTokens.TabNavigation.maximumVisibleTabCount)
        #expect(MySQLActivityMonitorView.MySQLActivitySection.allCases.count > LayoutTokens.TabNavigation.maximumVisibleTabCount)
        #expect(PostgresActivityMonitorView.PostgresActivitySection.allCases.count > LayoutTokens.TabNavigation.maximumVisibleTabCount)
    }

    @Test
    func errorLogFitsTheSharedTabNavigationTreatment() {
        #expect(ErrorLogViewModel.LogProduct.allCases.count <= LayoutTokens.TabNavigation.maximumVisibleTabCount)
    }
}
