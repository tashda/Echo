import EchoLocalStorage
import Foundation

nonisolated enum QueryHistoryEncoding {
    @concurrent static func encode(_ history: [QueryHistoryItem]) async -> Data? {
        try? LocalRecordEncoding.encode(history)
    }
}
