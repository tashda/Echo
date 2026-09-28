import SwiftUI
import SQLServerKit

struct ExtendedEventsSessionList: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    var onWatchLiveData: (String) -> Void = { _ in }

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
        .tableColumnAutoResize()
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

                // Group 4: Edit
                Button {
                    Task { await viewModel.prepareEditSession(name) }
                } label: {
                    Label("Edit Session", systemImage: "pencil")
                }

                Divider()

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

}
