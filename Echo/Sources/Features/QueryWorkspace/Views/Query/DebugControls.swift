import SwiftUI

/// Floating debug controls shown when debug mode is active.
/// Provides Step Over, Continue, and Stop buttons plus a variable inspector.
struct DebugControls: View {
    @Bindable var query: QueryEditorState
    let onStepOver: () -> Void
    let onContinue: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            controlBar
            if !query.debugVariables.isEmpty {
                variableInspector
            }
            statusLabel
        }
        .padding(SpacingTokens.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SpacingTokens.xs))
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.xs)
                .stroke(ColorTokens.Separator.primary, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: SpacingTokens.xs) {
            stepOverButton
            continueButton
            stopButton
            Spacer()
            statementCounter
        }
    }

    private var stepOverButton: some View {
        Button(action: onStepOver) {
            Image(systemName: "arrow.down.to.line")
                .font(TypographyTokens.standard.weight(.semibold))
                .padding(SpacingTokens.xxs)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!query.isDebugPaused)
        .help("Step Over (F10)")
        .accessibilityIdentifier("debug-step-over")
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Image(systemName: "play.fill")
                .font(TypographyTokens.standard.weight(.semibold))
                .padding(SpacingTokens.xxs)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!query.isDebugPaused)
        .help("Continue (F5)")
        .accessibilityIdentifier("debug-continue")
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Status.error)
                .padding(SpacingTokens.xxs)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help("Stop Debugging (Shift+F5)")
        .accessibilityIdentifier("debug-stop")
    }

    private var statementCounter: some View {
        Text("\(query.debugCurrentIndex + 1) / \(query.debugStatements.count)")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)
            .monospacedDigit()
    }

    // MARK: - Variable Inspector

    private var variableInspector: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text("Variables")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)

            ForEach(query.debugVariables) { variable in
                HStack(spacing: SpacingTokens.xs) {
                    Text(variable.name)
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Text.primary)
                    Spacer()
                    Text(variable.value)
                        .font(TypographyTokens.monospaced)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.5), in: RoundedRectangle(cornerRadius: SpacingTokens.xxs))
    }

    // MARK: - Status

    private var statusLabel: some View {
        HStack(spacing: SpacingTokens.xxs) {
            statusIcon
            Text(statusText)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var statusIcon: some View {
        Group {
            switch query.debugPhase {
            case .idle:
                Image(systemName: "circle")
            case .running:
                ProgressView()
                    .controlSize(.mini)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Status.success)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
        }
        .font(TypographyTokens.detail)
    }

    private var statusText: String {
        switch query.debugPhase {
        case .idle:
            return "Ready"
        case .running:
            return "Executing statement \(query.debugCurrentIndex + 1)..."
        case .paused(let index):
            return "Paused at statement \(index + 1)"
        case .completed:
            return "Debug session completed"
        case .failed(let msg):
            return "Failed: \(msg)"
        }
    }
}
