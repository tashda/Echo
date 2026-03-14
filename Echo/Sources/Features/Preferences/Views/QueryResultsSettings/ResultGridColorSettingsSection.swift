import SwiftUI

struct ResultGridColorSettingsSection: View {
    @Environment(ProjectStore.self) private var projectStore
    
    // Local preview state to avoid overwhelming the global store and triggering app-wide re-renders during drag
    @State private var previewOverrides: ResultGridColorOverrides?

    private var currentOverrides: ResultGridColorOverrides {
        previewOverrides ?? projectStore.globalSettings.resultGridColorOverrides
    }

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: SpacingTokens.md)
    ]

    var body: some View {
        Section(header: Text("Result Grid Colors"), footer: resetButton) {
            LazyVGrid(columns: columns, spacing: SpacingTokens.md) {
                colorCell(title: "NULL", keyPath: \.nullHex, defaultKind: .null)
                colorCell(title: "Numeric", keyPath: \.numericHex, defaultKind: .numeric)
                colorCell(title: "Boolean", keyPath: \.booleanHex, defaultKind: .boolean)
                colorCell(title: "Temporal", keyPath: \.temporalHex, defaultKind: .temporal)
                colorCell(title: "Binary", keyPath: \.binaryHex, defaultKind: .binary)
                colorCell(title: "Identifier", keyPath: \.identifierHex, defaultKind: .identifier)
                colorCell(title: "JSON", keyPath: \.jsonHex, defaultKind: .json)
                colorCell(title: "Text", keyPath: \.textHex, defaultKind: .text)
            }
            .padding(.vertical, SpacingTokens.sm)
        }
        .onAppear {
            previewOverrides = projectStore.globalSettings.resultGridColorOverrides
        }
        .onChange(of: projectStore.globalSettings.resultGridColorOverrides) { _, newValue in
            // Sync local preview if store changes externally (e.g. from another window or reset)
            previewOverrides = newValue
        }
    }

    private var resetButton: some View {
        HStack {
            Spacer()
            Button("Reset All to Theme Defaults") {
                var settings = projectStore.globalSettings
                settings.resultGridColorOverrides = ResultGridColorOverrides()
                Task { try? await projectStore.updateGlobalSettings(settings) }
                previewOverrides = settings.resultGridColorOverrides
            }
            .buttonStyle(.link)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func colorCell(
        title: String,
        keyPath: WritableKeyPath<ResultGridColorOverrides, String?>,
        defaultKind: ResultGridValueKind
    ) -> some View {
        let currentHex = currentOverrides[keyPath: keyPath]
        
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            
            HStack(spacing: SpacingTokens.xs) {
                DebouncedColorPicker(
                    currentHex: currentHex,
                    defaultKind: defaultKind,
                    onColorChange: { hex in
                        // Update local preview immediately for real-time feedback
                        if previewOverrides == nil {
                            previewOverrides = projectStore.globalSettings.resultGridColorOverrides
                        }
                        previewOverrides?[keyPath: keyPath] = hex
                    },
                    onCommit: { hex in
                        // Commit to global store only after debounce delay
                        var settings = projectStore.globalSettings
                        settings.resultGridColorOverrides[keyPath: keyPath] = hex
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                )
                
                if currentHex != nil {
                    Button {
                        var settings = projectStore.globalSettings
                        settings.resultGridColorOverrides[keyPath: keyPath] = nil
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                        previewOverrides?[keyPath: keyPath] = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(TypographyTokens.compact)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to default")
                }
            }
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Background.secondary.opacity(0.5))
            .cornerRadius(6)
        }
    }
}

/// A ColorPicker that manages its own tracking state to remain "bullet-proof" against 
/// external re-renders and potential conversion precision loss.
private struct DebouncedColorPicker: View {
    let currentHex: String?
    let defaultKind: ResultGridValueKind
    let onColorChange: (String) -> Void
    let onCommit: (String) -> Void

    // The actual color being tracked by the picker during user interaction
    @State private var trackingColor: Color = .clear
    // A flag to prevent cycles during initial setup
    @State private var isInitialized = false
    // Debounce task for store persistence
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        ColorPicker("", selection: Binding(
            get: { trackingColor },
            set: { newColor in
                // 1. Update the UI state immediately
                trackingColor = newColor
                
                // 2. Extract hex for the store
                guard let hex = newColor.toHex() else { return }
                
                // 3. Notify parent for real-time preview (in-memory only)
                onColorChange(hex)
                
                // 4. Debounce the heavy disk save
                debounceTask?.cancel()
                debounceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    onCommit(hex)
                }
            }
        ), supportsOpacity: false)
            .labelsHidden()
            .onAppear {
                trackingColor = resolvedColor(hex: currentHex, kind: defaultKind)
                isInitialized = true
            }
            .onChange(of: currentHex) { _, newHex in
                // Only sync from store if we are NOT currently dragging (determined by hex match)
                // This prevents the "not responding" loop where store updates fight with the picker.
                if isInitialized && newHex != trackingColor.toHex() {
                    trackingColor = resolvedColor(hex: newHex, kind: defaultKind)
                }
            }
    }

    private func resolvedColor(hex: String?, kind: ResultGridValueKind) -> Color {
        if let hex, let color = Color(hex: hex) { return color }
        let tone: SQLEditorPalette.Tone = AppearanceStore.shared.effectiveColorScheme == .dark ? .dark : .light
        let defaults = SQLEditorTokenPalette.ResultGridColors.defaults(for: tone)
        return defaults.style(for: kind).color.color
    }
}
