import SwiftUI

struct ActivityMonitorToolbar<SectionPicker: View>: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @ViewBuilder let sectionPicker: () -> SectionPicker

    var body: some View {
        TabSectionToolbar {
            sectionPicker()
        } controls: {
            HStack(spacing: SpacingTokens.xs) {
                Button {
                    if viewModel.isRunning {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.startStreaming()
                    }
                } label: {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .help(viewModel.isRunning ? "Pause Monitoring" : "Resume Monitoring")

                Picker(selection: $viewModel.refreshInterval) {
                    Text("1s").tag(TimeInterval(1.0))
                    Text("2s").tag(TimeInterval(2.0))
                    Text("5s").tag(TimeInterval(5.0))
                    Text("10s").tag(TimeInterval(10.0))
                } label: {
                    EmptyView()
                }
                .pickerStyle(.menu)
                .frame(width: 60)
                .onChange(of: viewModel.refreshInterval) { _, _ in
                    if viewModel.isRunning { viewModel.startStreaming() }
                }
            }

            if let last = viewModel.latestSnapshot {
                HStack(spacing: SpacingTokens.xxs) {
                    Circle()
                        .fill(viewModel.isRunning ? ColorTokens.Status.success : ColorTokens.Text.quaternary)
                        .frame(width: 6, height: 6)
                    Text(last.capturedAt, style: .time)
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
    }
}
