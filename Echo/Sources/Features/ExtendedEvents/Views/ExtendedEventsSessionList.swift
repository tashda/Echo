import SwiftUI
import SQLServerKit

struct ExtendedEventsSessionList: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    @Environment(AppState.self) private var appState
    @Environment(EnvironmentState.self) private var environmentState
    
    @State private var splitFraction: CGFloat = 0.4

    var body: some View {
        NativeSplitView(
            isVertical: false, // Top/Bottom split like Agent Jobs
            firstMinFraction: 0.2,
            secondMinFraction: 0.3,
            fraction: $splitFraction
        ) {
            sessionTable
        } second: {
            detailPane
        }
        .background(ColorTokens.Background.primary)
    }

    // MARK: - Session Table

    private var sessionTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    ToolbarAddButton()
                }
                .buttonStyle(.plain)
                .help("New Extended Events Session")
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)

            Divider()

            Table(viewModel.sessions, selection: Binding(
                get: { Set([viewModel.selectedSessionName].compactMap { $0 }) },
                set: { names in 
                    if let first = names.first {
                        Task { await viewModel.selectSession(first) }
                    }
                }
            )) {
                TableColumn("Name", value: \.name)
                TableColumn("Status") { session in
                    Text(session.isRunning ? "Running" : "Stopped")
                        .font(TypographyTokens.statusLabel)
                        .foregroundStyle(session.isRunning ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                }
                TableColumn("Startup") { session in
                    Image(systemName: session.startupState ? "checkmark" : "minus")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(session.startupState ? ColorTokens.Text.secondary : ColorTokens.Text.quaternary)
                }
                .width(60)
            }
            .contextMenu(forSelectionType: String.self) { names in
                if let name = names.first, let session = viewModel.sessions.first(where: { $0.name == name }) {
                    Button {
                        Task { await viewModel.toggleSession(session) }
                    } label: {
                        Label(session.isRunning ? "Stop Session" : "Start Session", 
                              systemImage: session.isRunning ? "stop.fill" : "play.fill")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        Task { await viewModel.dropSession(name) }
                    } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
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
                
                HSplitView {
                    sessionProperties(sessionName)
                        .frame(minWidth: 250, maxWidth: 450)
                    
                    liveEventStream
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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

    private func sessionProperties(_ name: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                if let detail = viewModel.sessionDetail {
                    propertyTable(title: "Configured Events", items: detail.events.map { $0.eventName })
                    propertyTable(title: "Targets", items: detail.targets.map { $0.targetName })
                } else if viewModel.detailLoadingState != .loading {
                    Text("Session details not available.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(SpacingTokens.md)
        }
        .background(ColorTokens.Background.secondary.opacity(0.1))
    }

    private func propertyTable(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text(title)
                .font(TypographyTokens.standard.weight(.bold))
            
            VStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    Text("No items configured")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .padding(SpacingTokens.sm)
                } else {
                    ForEach(items, id: \.self) { item in
                        HStack {
                            Text(item)
                                .font(TypographyTokens.statusLabel)
                            Spacer()
                        }
                        .padding(.horizontal, SpacingTokens.sm)
                        .padding(.vertical, 6)
                        
                        if item != items.last {
                            Divider().padding(.leading, SpacingTokens.sm)
                        }
                    }
                }
            }
            .background(ColorTokens.Background.secondary.opacity(0.3))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorTokens.Background.tertiary.opacity(0.5), lineWidth: 0.5))
        }
    }

    private var liveEventStream: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Live Data")
                    .font(TypographyTokens.standard.weight(.semibold))
                Spacer()
                if viewModel.eventDataLoadingState == .loading {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)
            
            Divider()
            
            ExtendedEventsDataView(viewModel: viewModel)
        }
    }

    private var noSelectionPlaceholder: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.largeTitle)
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Select an Extended Events session to view properties and live data.")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
