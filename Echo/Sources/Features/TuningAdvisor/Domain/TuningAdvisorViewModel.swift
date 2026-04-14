import Foundation
import Observation
import SQLServerKit
import Logging

@Observable @MainActor
final class TuningAdvisorViewModel {
    var recommendations: [SQLServerMissingIndexRecommendation] = []
    var indexUsageStats: [SQLServerTuningClient.SQLServerIndexUsageStat] = []
    var isRefreshing = false
    var isCreatingIndex = false
    var selectedRecommendationID: Int?
    var errorMessage: String?
    var selectedTab: TuningTab = .missingIndexes

    enum TuningTab: String, CaseIterable {
        case missingIndexes = "Missing Indexes"
        case indexUsage = "Index Usage"
    }

    @ObservationIgnored private let tuningClient: SQLServerTuningClient?
    @ObservationIgnored let session: DatabaseSession?
    @ObservationIgnored let connectionSessionID: UUID
    @ObservationIgnored var activityEngine: ActivityEngine?
    private let logger = Logger(label: "TuningAdvisorViewModel")

    init(tuningClient: SQLServerTuningClient?, session: DatabaseSession?, connectionSessionID: UUID) {
        self.tuningClient = tuningClient
        self.session = session
        self.connectionSessionID = connectionSessionID
    }

    func refresh() {
        guard let client = tuningClient else { return }
        isRefreshing = true

        Task {
            do {
                recommendations = try await client.listMissingIndexRecommendations(minImpact: 0)
                isRefreshing = false
            } catch {
                logger.error("Failed to load recommendations: \(error)")
                isRefreshing = false
            }
        }
    }

    func loadIndexUsageStats() {
        guard let client = tuningClient else { return }
        isRefreshing = true
        Task {
            do {
                indexUsageStats = try await client.indexUsageStats()
                isRefreshing = false
            } catch {
                logger.error("Failed to load index usage stats: \(error)")
                isRefreshing = false
            }
        }
    }

    var selectedRecommendation: SQLServerMissingIndexRecommendation? {
        recommendations.first { $0.indexHandle == selectedRecommendationID }
    }

    func createIndex(sql: String, indexName: String) async {
        guard let session else { return }
        isCreatingIndex = true
        errorMessage = nil

        let handle = activityEngine?.begin("Creating index \(indexName)", connectionSessionID: connectionSessionID)
        do {
            _ = try await session.simpleQuery(sql)
            handle?.succeed()
            isCreatingIndex = false
            refresh()
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
            isCreatingIndex = false
        }
    }
}
