import SwiftUI
import SQLServerKit

extension ExtendedEventsSessionList {
    @ViewBuilder
    var detailPane: some View {
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
            TabContentUnavailableView("Details Unavailable", systemImage: "waveform.path.ecg") {
                Text("Session configuration details could not be loaded.")
            }
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
            .tableColumnAutoResize()
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
            .tableColumnAutoResize()
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
        TabContentUnavailableView("No Session Selected", systemImage: "waveform.path.ecg") {
            Text("Select a session to view its configuration.")
        }
    }
}
