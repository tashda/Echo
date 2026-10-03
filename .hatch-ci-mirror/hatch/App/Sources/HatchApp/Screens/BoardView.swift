import SwiftUI
import HatchCore

/// Five phase columns; each card shows its exact status chip (decision D2). A Theme gets a progress header (decision D4).
struct BoardView: View {
    @EnvironmentObject var state: AppState
    @State private var tickets: [Ticket] = []
    @State private var themes: [Ticket] = []
    @State private var projectNames: [Int: String] = [:]
    @State private var typeFilter: TicketType?
    @State private var themeId: Int?
    @State private var progress: (done: Int, total: Int) = (0, 0)

    private func column(_ phase: Phase) -> [Ticket] {
        tickets.filter { $0.status.phase == phase }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarRow
            if let theme = themes.first(where: { $0.id == themeId }) {
                ThemeHeader(theme: theme, done: progress.done, total: progress.total)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            Divider()
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Phase.allCases, id: \.self) { phase in
                        BoardColumn(phase: phase,
                                    tickets: column(phase),
                                    projectNames: projectNames,
                                    showProject: state.selectedProjectKey == nil && projectNames.count > 1)
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle("Board")
        .autoReload(every: 5) { load() }
        .onChange(of: typeFilter) { _, _ in load() }
        .onChange(of: themeId) { _, _ in load() }
    }

    private var toolbarRow: some View {
        HStack(spacing: 12) {
            Picker("Type", selection: $typeFilter) {
                Text("Type: any").tag(TicketType?.none)
                ForEach(TicketType.allCases.filter { $0 != .theme }, id: \.self) { type in
                    Text(type.displayName).tag(Optional(type))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 140)
            Picker("Theme", selection: $themeId) {
                Text("Theme: any").tag(Int?.none)
                ForEach(themes) { theme in
                    Text(theme.title).tag(Optional(theme.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 200)
            Spacer()
            Button {
                state.route = .tickets
            } label: {
                Label("List", systemImage: "list.bullet")
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func load() {
        let pid = state.projectFilterId
        var names: [Int: String] = [:]
        for project in state.projects { names[project.id] = project.name }
        projectNames = names
        let filter = TicketFilter(projectId: pid, types: typeFilter.map { [$0] }, parentId: themeId)
        let all: [Ticket] = (try? state.store.tickets(filter)) ?? []
        tickets = all.filter { $0.type != .theme }
        themes = ((try? state.store.tickets(TicketFilter(projectId: pid, types: [.theme]))) ?? []).filter { !$0.status.isTerminal || $0.id == themeId }
        if let themeId {
            progress = (try? state.store.themeProgress(themeId)) ?? (done: 0, total: 0)
        }
    }
}

struct BoardColumn: View {
    let phase: Phase
    let tickets: [Ticket]
    let projectNames: [Int: String]
    let showProject: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(phase.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("\(tickets.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tickets) { ticket in
                        BoardCard(ticket: ticket, projectName: projectNames[ticket.projectId] ?? "", showProject: showProject)
                    }
                }
            }
        }
        .frame(width: 230)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct BoardCard: View {
    @EnvironmentObject var state: AppState
    let ticket: Ticket
    let projectName: String
    let showProject: Bool

    var body: some View {
        Button {
            state.open(ticket)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TypeBadge(type: ticket.type, showName: false)
                    Text(ticket.displayNumber)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Format.relative(ticket.updatedAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(ticket.title)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    StatusChip(status: ticket.status)
                    if showProject && !projectName.isEmpty {
                        PlainChip(text: projectName)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }
}

/// "3 of 7 done" with a progress bar, shown above a Theme's tickets.
struct ThemeHeader: View {
    let theme: Ticket
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: Theme.symbol(for: .theme))
                Text(theme.title)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(done) of \(total) done")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(Theme.finished)
        }
    }
}
