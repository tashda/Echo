import SwiftUI
import SQLServerKit

struct ExtendedEventsSessionList: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    var onWatchLiveData: (String) -> Void = { _ in }
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState

    @State private var splitFraction: CGFloat = 0.45
    @State private var sessionSortOrder: [KeyPathComparator<SQLServerXESession>] = []
    @State private var dropSessionTarget: String?

    var body: some View {
        NativeSplitView(
            isVertical: true,
            firstMinFraction: 0.3,
            secondMinFraction: 0.3,
            fraction: $splitFraction
        ) {
            sessionTable
        } second: {
            detailPane
        }
        .background(ColorTokens.Background.primary)
        .alert(
            "Delete \"\(dropSessionTarget ?? "")\"?",
            isPresented: Binding(get: { dropSessionTarget != nil }, set: { if !$0 { dropSessionTarget = nil } })
        ) {
            Button("Cancel", role: .cancel) { dropSessionTarget = nil }
            Button("Delete", role: .destructive) {
                if let name = dropSessionTarget {
                    Task { await viewModel.dropSession(name) }
                }
                dropSessionTarget = nil
            }
        } message: {
            Text("This will permanently drop the Extended Events session from the server. This action cannot be undone.")
        }
    }

    // MARK: - Session Table

    private var sessionTable: some View {
        Table(viewModel.sessions.sorted(using: sessionSortOrder), selection: Binding(
            get: { Set([viewModel.selectedSessionName].compactMap { $0 }) },
            set: { names in
                if let first = names.first {
                    Task { await viewModel.selectSession(first) }
                }
            }
        ), sortOrder: $sessionSortOrder) {
            TableColumn("Name", value: \.name) { session in
                Text(session.name)
                    .font(TypographyTokens.Table.name)
            }
            TableColumn("Status") { session in
                Text(session.isRunning ? "Running" : "Stopped")
                    .font(TypographyTokens.Table.status)
                    .foregroundStyle(session.isRunning ? ColorTokens.Status.success : ColorTokens.Text.secondary)
            }
            TableColumn("Startup") { session in
                Image(systemName: session.startupState ? "checkmark" : "minus")
                    .font(TypographyTokens.compact)
                    .foregroundStyle(session.startupState ? ColorTokens.Text.secondary : ColorTokens.Text.quaternary)
            }
            .width(60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { names in
            if let name = names.first, let session = viewModel.sessions.first(where: { $0.name == name }) {
                // Group 2: New
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Label("New Session", systemImage: "waveform.badge.plus")
                }

                Divider()

                // Group 3: Open / View
                if session.isRunning {
                    Button {
                        onWatchLiveData(name)
                    } label: {
                        Label("Watch Live Data", systemImage: "waveform.path.ecg")
                    }
                }

                // Group 8: Enable / Disable
                Button {
                    Task { await viewModel.toggleSession(session) }
                } label: {
                    Label(session.isRunning ? "Stop Session" : "Start Session",
                          systemImage: session.isRunning ? "stop.fill" : "play.fill")
                }

                Divider()

                // Group 10: Destructive
                Button(role: .destructive) {
                    dropSessionTarget = name
                } label: {
                    Label("Delete Session", systemImage: "trash")
                }
            } else {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Label("New Session", systemImage: "waveform.badge.plus")
                }
            }
        }
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let sessionName = viewModel.selectedSessionName {
            VStack(alignment: .leading, spacing: 0) {
                detailHeader(sessionName)
                Divider()
                sessionDetailContent
            }
        } else {
            noSelectionPlaceholder
        }
    }

    private func detailHeader(_ sessionName: String) -> some View {
        HStack {
            Text(sessionName)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Spacer()
            if viewModel.detailLoadingState == .loading {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    @ViewBuilder
    private var sessionDetailContent: some View {
        if let detail = viewModel.sessionDetail {
            NativeSplitView(
                isVertical: false,
                firstMinFraction: 0.35,
                secondMinFraction: 0.25,
                fraction: .constant(0.65)
            ) {
                eventsTable(detail.events)
            } second: {
                targetsTable(detail.targets)
            }
        } else if viewModel.detailLoadingState != .loading {
            VStack {
                Text("Session details not available.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func eventsTable(_ events: [SQLServerXESessionEvent]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Configured Events")
            Divider()
            Table(events) {
                TableColumn("Event Name") { (event: SQLServerXESessionEvent) in
                    Text(event.eventName)
                        .font(TypographyTokens.Table.name)
                }
                TableColumn("Package") { (event: SQLServerXESessionEvent) in
                    Text(event.packageName)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                    .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private func targetsTable(_ targets: [SQLServerXESessionTarget]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Targets")
            Divider()
            Table(targets) {
                TableColumn("Target Name") { (target: SQLServerXESessionTarget) in
                    Text(target.targetName)
                        .font(TypographyTokens.Table.name)
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.detail.weight(.medium))
            .foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.xs)
    }

    private var noSelectionPlaceholder: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.largeTitle)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Select a session to view its configuration")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
