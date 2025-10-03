import SwiftUI

// Environment key for sharing the sidebar toggle namespace
struct SidebarToggleNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var sidebarToggleNamespace: Namespace.ID? {
        get { self[SidebarToggleNamespaceKey.self] }
        set { self[SidebarToggleNamespaceKey.self] = newValue }
    }
}
