import Foundation

protocol ResultSpoolCoordinatorProtocol: AnyObject, Sendable {
    func updateConfiguration(with settings: GlobalSettings) async
    func makeSpoolHandle() async throws -> ResultSpoolHandle
    func removeSpool(for id: UUID) async
}
