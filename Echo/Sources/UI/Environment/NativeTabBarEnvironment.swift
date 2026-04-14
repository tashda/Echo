import SwiftUI

private struct UseNativeTabBarKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var useNativeTabBar: Bool {
        get { self[UseNativeTabBarKey.self] }
        set { self[UseNativeTabBarKey.self] = newValue }
    }
}
