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

/// One global setting that Reset This Page can put back (round 43.5, RP0).
struct ResettableSetting {
    let apply: (inout GlobalSettings, GlobalSettings) -> Void

    init<Value>(_ keyPath: WritableKeyPath<GlobalSettings, Value>) {
        apply = { settings, defaults in settings[keyPath: keyPath] = defaults[keyPath: keyPath] }
    }
}

extension ProjectStore {
    /// The ↺ of a row (round 43.3, RS1): nil while the setting is at its default, otherwise puts it back.
    func resetAction<Value: Equatable>(_ keyPath: WritableKeyPath<GlobalSettings, Value>) -> (() -> Void)? {
        let defaults = GlobalSettings()
        guard globalSettings[keyPath: keyPath] != defaults[keyPath: keyPath] else { return nil }
        return {
            var settings = self.globalSettings
            settings[keyPath: keyPath] = defaults[keyPath: keyPath]
            Task { try? await self.updateGlobalSettings(settings) }
        }
    }

    /// Reset This Page: every listed setting goes back to its default in one save.
    func resetPage(_ settings: [ResettableSetting]) -> () -> Void {
        {
            let defaults = GlobalSettings()
            var updated = self.globalSettings
            for setting in settings { setting.apply(&updated, defaults) }
            Task { try? await self.updateGlobalSettings(updated) }
        }
    }
}
