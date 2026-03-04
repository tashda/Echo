import Foundation
import SwiftUI

private struct HostedWorkspaceTabKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var hostedWorkspaceTabID: UUID? {
        get { self[HostedWorkspaceTabKey.self] }
        set { self[HostedWorkspaceTabKey.self] = newValue }
    }
}
