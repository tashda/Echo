import Foundation
import Observation
import SQLServerKit
import Logging

@Observable @MainActor
final class TuningAdvisorViewModel {
    var recommendations: [SQLServerMissingIndexRecommendation] = []
    var isRefreshing = false
    var selectedRecommendationID: Int?
    
    private let tuningClient: SQLServerTuningClient?
    private let connectionSessionID: UUID
    private let logger = Logger(label: "TuningAdvisorViewModel")

    init(tuningClient: SQLServerTuningClient?, connectionSessionID: UUID) {
        self.tuningClient = tuningClient
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

    var selectedRecommendation: SQLServerMissingIndexRecommendation? {
        recommendations.first { $0.indexHandle == selectedRecommendationID }
    }
}
