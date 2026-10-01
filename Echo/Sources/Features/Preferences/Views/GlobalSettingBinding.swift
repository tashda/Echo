import SwiftUI

extension ProjectStore {
    /// A binding to one global setting that saves the change, skipping writes that change nothing.
    func globalSettingBinding<Value: Equatable>(_ keyPath: WritableKeyPath<GlobalSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.globalSettings[keyPath: keyPath] },
            set: { newValue in
                guard self.globalSettings[keyPath: keyPath] != newValue else { return }
                var settings = self.globalSettings
                settings[keyPath: keyPath] = newValue
                Task { try? await self.updateGlobalSettings(settings) }
            }
        )
    }
}
