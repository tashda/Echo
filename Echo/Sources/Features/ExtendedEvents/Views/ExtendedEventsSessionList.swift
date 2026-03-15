import SwiftUI
import SQLServerKit

struct ExtendedEventsSessionList: View {
    @Bindable var viewModel: ExtendedEventsViewModel

    var body: some View {
        HSplitView {
            sessionTable
                .frame(minWidth: 300)

            detailPanel
                .frame(minWidth: 250)
        }
    }

    // MARK: - Session Table

    private var sessionTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            tableHeader
            Divider()

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.sessions) { session in
                            sessionRow(session)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Session")
                .frame(minWidth: 150, alignment: .leading)
            Text("Status")
                .frame(width: 80, alignment: .center)
            Text("Startup")
                .frame(width: 70, alignment: .center)
            Text("Actions")
                .frame(width: 100, alignment: .trailing)
        }
        .font(TypographyTokens.compact.weight(.semibold))
        .foregroundStyle(ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    private func sessionRow(_ session: SQLServerXESession) -> some View {
        let isSelected = viewModel.selectedSessionName == session.name
        let isToggling = viewModel.togglingSessionName == session.name

        return HStack(spacing: 0) {
            Text(session.name)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.primary)
                .frame(minWidth: 150, alignment: .leading)
                .lineLimit(1)

            HStack(spacing: SpacingTokens.xxxs) {
                Circle()
                    .fill(session.isRunning ? ColorTokens.Status.success : ColorTokens.Text.quaternary)
                    .frame(width: 7, height: 7)
                Text(session.isRunning ? "Running" : "Stopped")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(width: 80, alignment: .center)

            Image(systemName: session.startupState ? "checkmark" : "minus")
                .font(TypographyTokens.compact)
                .foregroundStyle(session.startupState ? ColorTokens.Text.secondary : ColorTokens.Text.quaternary)
                .frame(width: 70, alignment: .center)

            HStack(spacing: SpacingTokens.xs) {
                Button {
                    Task { await viewModel.toggleSession(session) }
                } label: {
                    Image(systemName: session.isRunning ? "stop.fill" : "play.fill")
                        .font(TypographyTokens.compact)
                }
                .buttonStyle(.borderless)
                .disabled(isToggling)
                .help(session.isRunning ? "Stop session" : "Start session")

                Button(role: .destructive) {
                    Task { await viewModel.dropSession(session.name) }
                } label: {
                    Image(systemName: "trash")
                        .font(TypographyTokens.compact)
                }
                .buttonStyle(.borderless)
                .help("Drop session")
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
        .background(isSelected ? ColorTokens.accent.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await viewModel.selectSession(session.name) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("No Extended Events sessions")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Create a session to start capturing events.")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let sessionName = viewModel.selectedSessionName {
                detailHeader(sessionName)
                Divider()

                if viewModel.detailLoadingState == .loading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = viewModel.sessionDetail {
                    detailContent(detail)
                }
            } else {
                noSelectionPlaceholder
            }
        }
    }

    private func detailHeader(_ sessionName: String) -> some View {
        HStack {
            Text(sessionName)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Spacer()
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    private func detailContent(_ detail: SQLServerXESessionDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                detailEventsSection(detail.events)
                detailTargetsSection(detail.targets)
            }
            .padding(SpacingTokens.md)
        }
    }

    private func detailEventsSection(_ events: [SQLServerXESessionEvent]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Events (\(events.count))")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            if events.isEmpty {
                Text("Session is not running — start it to view events.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(events) { event in
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "bolt")
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.eventName)
                                .font(TypographyTokens.standard)
                                .foregroundStyle(ColorTokens.Text.primary)
                            Text(event.packageName)
                                .font(TypographyTokens.compact)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                    .padding(.vertical, SpacingTokens.xxxs)
                }
            }
        }
    }

    private func detailTargetsSection(_ targets: [SQLServerXESessionTarget]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Targets (\(targets.count))")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)

            if targets.isEmpty {
                Text("Session is not running — start it to view targets.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(targets) { target in
                    HStack(spacing: SpacingTokens.xs) {
                        Image(systemName: "target")
                            .font(TypographyTokens.compact)
                            .foregroundStyle(ColorTokens.Text.secondary)
                        Text(target.targetName)
                            .font(TypographyTokens.standard)
                            .foregroundStyle(ColorTokens.Text.primary)
                    }
                    .padding(.vertical, SpacingTokens.xxxs)
                }
            }
        }
    }

    private var noSelectionPlaceholder: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "sidebar.right")
                .font(.title2)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Select a session to view details")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
