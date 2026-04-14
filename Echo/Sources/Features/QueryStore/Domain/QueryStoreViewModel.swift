import Foundation
import SwiftUI
import SQLServerKit

/// View model for the Query Store panel, managing data loading and state.
@Observable
final class QueryStoreViewModel {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    enum SelectedSection: String, CaseIterable {
        case topQueries = "Top Queries"
        case regressedQueries = "Regressed Queries"
    }

    @ObservationIgnored private let queryStoreClient: SQLServerQueryStoreClient
    @ObservationIgnored let databaseName: String
    @ObservationIgnored let connectionSessionID: UUID

    var loadingState: LoadingState = .idle
    var storeOptions: SQLServerQueryStoreOptions?
    var topQueries: [SQLServerQueryStoreTopQuery] = []
    var regressedQueries: [SQLServerQueryStoreRegressedQuery] = []
    var selectedSection: SelectedSection = .topQueries
    var selectedQueryId: Int?
    var queryPlans: [SQLServerQueryStorePlan] = []
    var plansLoadingState: LoadingState = .idle
    var waitStats: [SQLServerQueryStoreClient.SQLServerQueryStoreWaitStat] = []
    var orderBy: SQLServerQueryStoreTopQueryOrder = .totalDuration
    var forcingPlanId: Int?

    // Filters
    var filterTimeRange: TimeRange = .lastDay
    var filterQueryText = ""
    var filterMinExecutions = 1

    enum TimeRange: String, CaseIterable {
        case lastHour = "Last Hour"
        case lastDay = "Last 24 Hours"
        case lastWeek = "Last 7 Days"
        case allTime = "All Time"

        var startDate: Date? {
            switch self {
            case .lastHour: return Date().addingTimeInterval(-3600)
            case .lastDay: return Date().addingTimeInterval(-86400)
            case .lastWeek: return Date().addingTimeInterval(-604800)
            case .allTime: return nil
            }
        }
    }

    init(
        queryStoreClient: SQLServerQueryStoreClient,
        databaseName: String,
        connectionSessionID: UUID
    ) {
        self.queryStoreClient = queryStoreClient
        self.databaseName = databaseName
        self.connectionSessionID = connectionSessionID
    }

    func loadAll() async {
        loadingState = .loading
        do {
            let opts = try await queryStoreClient.options(database: databaseName)
            let textFilter = filterQueryText.trimmingCharacters(in: .whitespacesAndNewlines)
            let top = try await queryStoreClient.topQueries(
                database: databaseName,
                limit: 25,
                orderBy: orderBy,
                startDate: filterTimeRange.startDate,
                minExecutionCount: filterMinExecutions > 1 ? filterMinExecutions : nil,
                queryTextFilter: textFilter.isEmpty ? nil : textFilter
            )
            let regressed = try await queryStoreClient.regressedQueries(database: databaseName, limit: 20)
            storeOptions = opts
            topQueries = top
            regressedQueries = regressed
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    func refreshOptions() async {
        do {
            let previousState = storeOptions?.actualState
            let opts = try await queryStoreClient.options(database: databaseName)
            storeOptions = opts
            // If the state changed (e.g. turned on/off), do a full reload
            if previousState != opts.actualState {
                await loadAll()
            }
        } catch {
            // Silently fail — options will show stale data
        }
    }

    func refreshTopQueries() async {
        do {
            let textFilter = filterQueryText.trimmingCharacters(in: .whitespacesAndNewlines)
            topQueries = try await queryStoreClient.topQueries(
                database: databaseName,
                limit: 25,
                orderBy: orderBy,
                startDate: filterTimeRange.startDate,
                minExecutionCount: filterMinExecutions > 1 ? filterMinExecutions : nil,
                queryTextFilter: textFilter.isEmpty ? nil : textFilter
            )
        } catch {
            loadingState = .error(error.localizedDescription)
        }
    }

    func selectQuery(_ queryId: Int) async {
        selectedQueryId = queryId
        plansLoadingState = .loading
        waitStats = []
        do {
            queryPlans = try await queryStoreClient.queryPlans(
                database: databaseName, queryId: queryId
            )
            // Load wait stats for the first plan
            if let firstPlan = queryPlans.first {
                waitStats = try await queryStoreClient.waitStats(
                    database: databaseName, planId: firstPlan.planId
                )
            }
            plansLoadingState = .loaded
        } catch {
            plansLoadingState = .error(error.localizedDescription)
        }
    }

    func forcePlan(queryId: Int, planId: Int) async {
        forcingPlanId = planId
        do {
            try await queryStoreClient.forcePlan(
                database: databaseName, queryId: queryId, planId: planId
            )
            // Refresh plans to show the updated forced state
            await selectQuery(queryId)
        } catch {
            plansLoadingState = .error(error.localizedDescription)
        }
        forcingPlanId = nil
    }

    func unforcePlan(queryId: Int, planId: Int) async {
        forcingPlanId = planId
        do {
            try await queryStoreClient.unforcePlan(
                database: databaseName, queryId: queryId, planId: planId
            )
            await selectQuery(queryId)
        } catch {
            plansLoadingState = .error(error.localizedDescription)
        }
        forcingPlanId = nil
    }

    func estimatedMemoryUsageBytes() -> Int {
        let queriesSize = topQueries.count * 256
        let regressedSize = regressedQueries.count * 256
        let plansSize = queryPlans.count * 1024
        return 1024 * 128 + queriesSize + regressedSize + plansSize
    }
}
