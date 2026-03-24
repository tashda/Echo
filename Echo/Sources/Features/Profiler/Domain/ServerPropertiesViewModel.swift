import Foundation
import Observation

@Observable @MainActor
final class ServerPropertiesViewModel {
    let connectionSessionID: UUID
    
    init(connectionSessionID: UUID) {
        self.connectionSessionID = connectionSessionID
    }
}
