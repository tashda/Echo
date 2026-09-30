import EchoSense
import Observation

/// The connection shared by the Test pages, so a schema loaded on Connections can be tried in
/// EchoSense without copying anything.
@Observable @MainActor
final class LabLiveSession {
    static let shared = LabLiveSession()

    var connection: LabLiveConnection?
    let profiles = LabConnectionProfile.load()
}
