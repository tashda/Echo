import SwiftUI
import HatchCore

/// A parsed filter bar: `type:bug status:to-verify project:echo turn:you` plus free words (decision D3).
struct TicketQuery {
    var types: [TicketType] = []
    var statuses: [Status] = []
    var turn: Turn?
    var projectKey: String?
    var area: String?
    var text: String = ""

    static let keys: [String] = ["type", "status", "project", "turn", "area"]

    static func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "_", with: "-").replacingOccurrences(of: " ", with: "-")
    }

    static func parse(_ input: String) -> TicketQuery {
        var q = TicketQuery()
        var words: [String] = []
        for raw in input.split(separator: " ") {
            let word = String(raw)
            guard let colon = word.firstIndex(of: ":") else { words.append(word); continue }
            let key = String(word[word.startIndex..<colon]).lowercased()
            let value = String(word[word.index(after: colon)...])
            guard keys.contains(key), !value.isEmpty else { words.append(word); continue }
            let values: [String] = value.split(separator: ",").map { normalize(String($0)) }
            switch key {
            case "type":
                for v in values { if let t = TicketType(rawValue: v) { q.types.append(t) } }
            case "status":
                for v in values {
                    if let s = Status.allCases.first(where: { $0.rawValue == v || normalize($0.displayName) == v }) { q.statuses.append(s) }
                }
            case "turn":
                if let v = values.first {
                    switch v {
                    case "you", "me", "mine": q.turn = .you
                    case "agent", "agents": q.turn = .agent
                    case "hatch": q.turn = .hatch
                    case "finished", "done": q.turn = .finished
                    case "paused": q.turn = .paused
                    default: break
                    }
                }
            case "project":
                q.projectKey = values.first
            case "area":
                q.area = values.first
            default:
                break
            }
        }
        q.text = words.joined(separator: " ")
        return q
    }
}

struct SavedView: Codable, Identifiable, Equatable {
    var name: String
    var query: String
    var id: String { name }
}

enum TicketSort: String, CaseIterable, Identifiable {
    case newest, oldest, number, title
    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: "Recently changed"
        case .oldest: "Longest waiting"
        case .number: "Number"
        case .title: "Title"
        }
    }
}

struct TicketsView: View {
    @EnvironmentObject var state: AppState
    @State private var queryText: String = ""
    @State private var tickets: [Ticket] = []
    @State private var selection: Set<Int> = []
    @State private var groupByTheme = false
    @State private var sort: TicketSort = .newest
    @State private var views: [SavedView] = []
    @State private var showSave = false
    @State private var newViewName = ""
    @State private var themeTitles: [Int: Ticket] = [:]
    @State private var projectNames: [Int: String] = [:]
    /// A saved view chosen in the sidebar (decision D3) arrives here; the sidebar cannot reach this view's state.
    @AppStorage("hatch.pendingTicketQuery") private var pendingQuery = ""

    static let defaultViews: [SavedView] = [
        SavedView(name: "Waiting for me", query: "turn:you"),
        SavedView(name: "Waiting on agents", query: "turn:agent"),
        SavedView(name: "Bugs to verify", query: "type:bug status:to-verify"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            if tickets.isEmpty {
                ContentUnavailableView("No tickets match", systemImage: "line.3.horizontal.decrease.circle",
                                       description: Text("Change the filter, or clear it to see everything."))
            } else if groupByTheme {
                groupedList
            } else {
                table
            }
        }
        .navigationTitle("Tickets")
        .autoReload(every: 6) { load() }
        .onChange(of: queryText) { _, _ in load() }
        .onChange(of: sort) { _, _ in load() }
        .onAppear { loadViews(); takePendingQuery() }
        .onChange(of: pendingQuery) { _, _ in takePendingQuery() }
        .searchable(text: $queryText, prompt: "type:bug status:to-verify project:echo turn:you, or words")
        .alert("Save this view", isPresented: $showSave) {
            TextField("Name", text: $newViewName)
            Button("Save") { saveCurrentView() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The filter \"\(queryText)\" is saved under this name.")
        }
    }

    // MARK: Filter bar

    private var filterBar: some View {
        HStack(spacing: 10) {
            addFilterMenu
            viewsMenu
            Spacer()
            Picker("Sort", selection: $sort) {
                ForEach(TicketSort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
            Toggle("Group by Theme", isOn: $groupByTheme)
                .toggleStyle(.switch)
                .controlSize(.small)
            Text(Format.count(tickets.count, "ticket"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var addFilterMenu: some View {
        Menu {
            Menu("Type") {
                ForEach(TicketType.allCases, id: \.self) { type in
                    Button(type.displayName) { addToken("type:\(type.rawValue)") }
                }
            }
            Menu("Status") {
                ForEach(Status.allCases, id: \.self) { status in
                    Button(status.displayName) { addToken("status:\(status.rawValue)") }
                }
            }
            Menu("Turn") {
                Button("Your turn") { addToken("turn:you") }
                Button("Agent's turn") { addToken("turn:agent") }
                Button("Hatch") { addToken("turn:hatch") }
            }
            Menu("Project") {
                ForEach(state.projects) { project in
                    Button(project.name) { addToken("project:\(project.key)") }
                }
            }
        } label: {
            Label("Filter", systemImage: "plus.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var viewsMenu: some View {
        Menu {
            ForEach(views) { view in
                Button(view.name) { queryText = view.query }
            }
            Divider()
            Button("Save current filter as a view…") {
                newViewName = ""
                showSave = true
            }
            .disabled(queryText.trimmingCharacters(in: .whitespaces).isEmpty)
            if !views.isEmpty {
                Menu("Delete a view") {
                    ForEach(views) { view in
                        Button(view.name) { deleteView(view) }
                    }
                }
            }
        } label: {
            Label("Views", systemImage: "bookmark")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: Table

    private var table: some View {
        Table(tickets, selection: $selection) {
            TableColumn("Type") { ticket in
                TypeBadge(type: ticket.type)
            }
            .width(min: 80, ideal: 92, max: 110)
            TableColumn("#") { ticket in
                Text(ticket.displayNumber)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 50, ideal: 64, max: 90)
            TableColumn("Title") { ticket in
                Text(ticket.title).lineLimit(1)
            }
            .width(min: 220, ideal: 360)
            TableColumn("Status") { ticket in
                StatusChip(status: ticket.status)
            }
            .width(min: 100, ideal: 120, max: 150)
            TableColumn("Turn") { ticket in
                TurnLabel(turn: ticket.turn)
            }
            .width(min: 80, ideal: 100, max: 120)
            TableColumn("Project") { ticket in
                Text(projectNames[ticket.projectId] ?? "")
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80, max: 120)
            TableColumn("Area") { ticket in
                Text(ticket.area ?? "")
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 100, max: 160)
            TableColumn("Age") { ticket in
                Text(Format.relative(ticket.updatedAt))
                    .foregroundStyle(.secondary)
            }
            .width(min: 40, ideal: 48, max: 70)
        }
        .contextMenu(forSelectionType: Int.self) { ids in
            if let id = ids.first {
                Button("Open") { openTicket(id) }
                Button("Park") { parkTicket(id) }
            }
        } primaryAction: { ids in
            if let id = ids.first { openTicket(id) }
        }
    }

    // MARK: Grouped by Theme

    private struct ThemeGroup: Identifiable {
        let theme: Ticket?
        let children: [Ticket]
        var id: Int { theme?.id ?? -1 }
    }

    private var groups: [ThemeGroup] {
        var byParent: [Int: [Ticket]] = [:]
        var loose: [Ticket] = []
        for ticket in tickets where ticket.type != .theme {
            if let parent = ticket.parentId { byParent[parent, default: []].append(ticket) } else { loose.append(ticket) }
        }
        var out: [ThemeGroup] = []
        for key in byParent.keys.sorted() {
            out.append(ThemeGroup(theme: themeTitles[key], children: byParent[key] ?? []))
        }
        if !loose.isEmpty { out.append(ThemeGroup(theme: nil, children: loose)) }
        return out
    }

    private var groupedList: some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.children) { ticket in
                        TicketLine(ticket: ticket, projectName: projectNames[ticket.projectId] ?? "")
                            .contentShape(Rectangle())
                            .onTapGesture { state.open(ticket) }
                    }
                } header: {
                    themeHeader(group)
                }
            }
        }
        .listStyle(.inset)
    }

    private func themeHeader(_ group: ThemeGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: Theme.symbol(for: .theme))
            Text(group.theme?.title ?? "No Theme")
                .font(.subheadline.weight(.semibold))
            if let theme = group.theme {
                let progress = (try? state.store.themeProgress(theme.id)) ?? (done: 0, total: 0)
                Text("\(progress.done) of \(progress.total) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: Data

    private func load() {
        let q = TicketQuery.parse(queryText)
        var names: [Int: String] = [:]
        for project in state.projects { names[project.id] = project.name }
        projectNames = names
        var projectId: Int? = state.projectFilterId
        if let key = q.projectKey {
            let match = state.projects.first { TicketQuery.normalize($0.key) == key || TicketQuery.normalize($0.name) == key }
            projectId = match?.id ?? projectId
        }
        let trimmed = q.text.trimmingCharacters(in: .whitespaces)
        let filter = TicketFilter(projectId: projectId,
                                  statuses: q.statuses.isEmpty ? nil : q.statuses,
                                  types: q.types.isEmpty ? nil : q.types,
                                  turn: q.turn,
                                  text: trimmed.isEmpty ? nil : trimmed)
        var result: [Ticket] = (try? state.store.tickets(filter)) ?? []
        if let area = q.area {
            result = result.filter { TicketQuery.normalize($0.area ?? "").contains(area) }
        }
        let ranked: Bool = !trimmed.isEmpty && sort == .newest
        if !ranked {
            switch sort {
            case .newest: result.sort { $0.updatedAt > $1.updatedAt }
            case .oldest: result.sort { $0.updatedAt < $1.updatedAt }
            case .number: result.sort { $0.id > $1.id }
            case .title: result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            }
        }
        tickets = result
        var themes: [Int: Ticket] = [:]
        for ticket in result {
            if let parent = ticket.parentId, themes[parent] == nil, let theme = try? state.store.ticket(id: parent) {
                themes[parent] = theme
            }
        }
        themeTitles = themes
    }

    private func addToken(_ token: String) {
        let trimmed = queryText.trimmingCharacters(in: .whitespaces)
        queryText = trimmed.isEmpty ? token + " " : trimmed + " " + token + " "
    }

    private func openTicket(_ id: Int) {
        if let ticket = tickets.first(where: { $0.id == id }) { state.open(ticket) }
    }

    private func parkTicket(_ id: Int) {
        _ = state.perform("Could not park the ticket") { try state.store.move(id, to: .parked, actor: .owner, reason: "parked from Tickets") }
    }

    // MARK: Saved views

    private func takePendingQuery() {
        guard !pendingQuery.isEmpty else { return }
        queryText = pendingQuery
        pendingQuery = ""
    }

    private func loadViews() {
        guard let json = (try? state.store.setting("views")) ?? nil,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([SavedView].self, from: data) else {
            views = Self.defaultViews
            return
        }
        views = decoded
    }

    private func persistViews() {
        guard let data = try? JSONEncoder().encode(views) else { return }
        let json = String(decoding: data, as: UTF8.self)
        _ = state.perform("Could not save the view") { try state.store.setSetting("views", json) }
    }

    private func saveCurrentView() {
        let name = newViewName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        views.removeAll { $0.name == name }
        views.append(SavedView(name: name, query: queryText))
        persistViews()
    }

    private func deleteView(_ view: SavedView) {
        views.removeAll { $0.name == view.name }
        persistViews()
    }
}

/// A compact ticket line for grouped lists.
struct TicketLine: View {
    let ticket: Ticket
    let projectName: String

    var body: some View {
        HStack(spacing: 10) {
            TypeBadge(type: ticket.type, showName: false)
            Text(ticket.displayNumber)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(ticket.title).lineLimit(1)
            Spacer(minLength: 8)
            StatusChip(status: ticket.status)
            Text(Format.relative(ticket.updatedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 30, alignment: .trailing)
        }
    }
}
