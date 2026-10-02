import Foundation

extension Array where Element == RecentConnectionRecord {
    /// The records without any for this connection (every database and user it was used with).
    func removing(connectionID: UUID) -> [RecentConnectionRecord] {
        filter { $0.id != connectionID }
    }
}
