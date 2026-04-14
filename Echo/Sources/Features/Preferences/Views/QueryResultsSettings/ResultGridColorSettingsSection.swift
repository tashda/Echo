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
            .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small))
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
        MinimalColorWell(
            color: Binding(
                get: { trackingColor },
                set: { newColor in
                    trackingColor = newColor
                    guard let hex = newColor.toHex() else { return }
                    onColorChange(hex)
                    debounceTask?.cancel()
                    debounceTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        onCommit(hex)
                    }
                }
            )
        )
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

/// An NSColorWell with `.minimal` style — no bordered background.
private struct MinimalColorWell: NSViewRepresentable {
    @Binding var color: Color

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell(style: .minimal)
        well.supportsAlpha = false
        well.color = NSColor(color)
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        return well
    }

    func updateNSView(_ well: NSColorWell, context: Context) {
        let newNSColor = NSColor(color)
        // Only update if meaningfully different to avoid fighting the picker during drag
        if !well.color.approximatelyEquals(newNSColor) {
            well.color = newNSColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(color: $color)
    }

    @MainActor final class Coordinator: NSObject {
        var color: Binding<Color>

        init(color: Binding<Color>) {
            self.color = color
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            color.wrappedValue = Color(nsColor: sender.color)
        }
    }
}

private extension NSColor {
    func approximatelyEquals(_ other: NSColor, tolerance: CGFloat = 0.01) -> Bool {
        guard let a = usingColorSpace(.sRGB), let b = other.usingColorSpace(.sRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < tolerance
            && abs(a.greenComponent - b.greenComponent) < tolerance
            && abs(a.blueComponent - b.blueComponent) < tolerance
    }
}
