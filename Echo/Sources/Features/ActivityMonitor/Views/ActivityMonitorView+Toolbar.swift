import SwiftUI

extension ActivityMonitorView {
    var toolbar: some View {
        HStack {
            HStack(spacing: SpacingTokens.sm) {
                Button(action: {
                    if viewModel.isRunning {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.startStreaming()
                    }
                }) {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .padding(SpacingTokens.xxs2)
                .background(ColorTokens.Background.tertiary)
                .cornerRadius(6)
                .help(viewModel.isRunning ? "Pause Monitoring" : "Resume Monitoring")

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .padding(SpacingTokens.xxs2)
                .background(ColorTokens.Background.tertiary)
                .cornerRadius(6)
                .help("Force Refresh")
            }

            Divider().frame(height: 16).padding(.horizontal, SpacingTokens.xs)

            HStack(spacing: SpacingTokens.xs) {
                Text("Refresh Every:")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)

                Picker("", selection: $viewModel.refreshInterval) {
                    Text("1s").tag(TimeInterval(1.0))
                    Text("2s").tag(TimeInterval(2.0))
                    Text("5s").tag(TimeInterval(5.0))
                    Text("10s").tag(TimeInterval(10.0))
                }
                .pickerStyle(.menu)
                .frame(width: 70)
                .labelsHidden()
                .onChange(of: viewModel.refreshInterval) { _, _ in
                    if viewModel.isRunning { viewModel.startStreaming() }
                }
            }

            Spacer()

            if let last = viewModel.latestSnapshot {
                HStack(spacing: SpacingTokens.xxs) {
                    Circle()
                        .fill(viewModel.isRunning ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                        .frame(width: 6, height: 6)
                    Text("Last update: \(last.capturedAt, style: .time)")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(ColorTokens.Background.secondary)
        .overlay(Divider(), alignment: .bottom)
    }
}
