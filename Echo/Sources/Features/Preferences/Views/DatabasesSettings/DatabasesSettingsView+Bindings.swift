import SwiftUI

extension DatabasesSettingsView {

    // MARK: - Streaming Bindings

    var initialRowLimitBinding: Binding<Int> {
        intBinding(for: \.resultsInitialRowLimit, min: 100, max: 100_000)
    }

    var previewBatchSizeBinding: Binding<Int> {
        intBinding(for: \.resultsPreviewBatchSize, min: 100, max: 100_000)
    }

    var backgroundStreamingThresholdBinding: Binding<Int> {
        intBinding(for: \.resultsBackgroundStreamingThreshold, min: 100, max: 1_000_000)
    }

    var backgroundFetchSizeBinding: Binding<Int> {
        intBinding(for: \.resultsStreamingFetchSize, min: 128, max: 16_384)
    }

    var fetchRampMultiplierBinding: Binding<Int> {
        intBinding(for: \.resultsStreamingFetchRampMultiplier, min: 1, max: 64)
    }

    var fetchRampMaxBinding: Binding<Int> {
        intBinding(for: \.resultsStreamingFetchRampMax, min: 256, max: 1_048_576)
    }

    var cursorLimitThresholdBinding: Binding<Int> {
        intBinding(for: \.resultsCursorStreamingLimitThreshold, min: 0, max: 1_000_000)
    }

    // MARK: - Engine Mode Bindings

    var postgresModeBinding: Binding<ResultStreamingExecutionMode> {
        binding(for: \.resultsStreamingMode)
    }

    var mssqlModeBinding: Binding<ResultStreamingExecutionMode> {
        binding(for: \.mssqlStreamingMode)
    }

    // MARK: - PostgreSQL Tool Bindings

    var managedConsoleBinding: Binding<Bool> {
        binding(for: \.managedPostgresConsoleEnabled)
    }

    var nativePsqlBinding: Binding<Bool> {
        binding(for: \.nativePsqlEnabled)
    }

    var runtimePreferenceBinding: Binding<NativePsqlRuntimePreference> {
        binding(for: \.nativePsqlRuntimePreference)
    }

    var systemFallbackBinding: Binding<Bool> {
        binding(for: \.nativePsqlAllowSystemBinaryFallback)
    }

    var shellEscapeBinding: Binding<Bool> {
        binding(for: \.nativePsqlAllowShellEscape)
    }

    var fileCommandsBinding: Binding<Bool> {
        binding(for: \.nativePsqlAllowFileCommands)
    }

    // MARK: - Formatters

    func formatMultiplier(_ value: Int) -> String {
        "\(value)x"
    }

    func formatRowCount(_ value: Int) -> String {
        value.formatted()
    }

    // MARK: - Generic Binding Helpers

    func binding<Value>(for keyPath: WritableKeyPath<GlobalSettings, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                var updated = settings
                updated[keyPath: keyPath] = newValue
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }

    func intBinding(for keyPath: WritableKeyPath<GlobalSettings, Int>, min: Int, max: Int) -> Binding<Int> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                let clamped = Swift.max(min, Swift.min(newValue, max))
                guard settings[keyPath: keyPath] != clamped else { return }
                var updated = settings
                updated[keyPath: keyPath] = clamped
                Task { try? await projectStore.updateGlobalSettings(updated) }
            }
        )
    }
}
