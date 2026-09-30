import EchoSenseScenarios
import SwiftUI

/// Test › Scenarios, laid out like Mail: filters with counts on the left, the scenarios in the middle
/// (each says what is wrong in a few words), and the one being judged on the right. Y and N answer
/// "is this what should happen?"; ↑ and ↓ move through the list. It opens on what is left to review.
struct ScenariosTestPage: View {
    @State private var store = ScenarioStore.shared
    @AppStorage("lab.scenarios.selected") private var selectedID: String?
    @AppStorage("lab.scenarios.filter.result") private var outcomeFilter = ""
    @AppStorage("lab.scenarios.filter.review") private var reviewFilter = ScenarioReview.imported.rawValue
    @AppStorage("lab.scenarios.filter.area") private var areaFilter = ""
    @AppStorage("lab.scenarios.filter.thread") private var threadFilter = ""
    @AppStorage("lab.scenarios.filter.rule") private var ruleFilter = ""
    @State private var search = ""
    @State private var isEditing = false
    /// Set when a new scenario is selected so it opens in the editor.
    @State private var editsNextSelection = false
    /// Where to go after answering, worked out before the answer can take the scenario out of the list.
    @State private var nextAfterAnswer: String?
    @FocusState private var listFocused: Bool

    var body: some View {
        Group {
            if let error = store.loadError, store.scenarios.isEmpty {
                ContentUnavailableView("No scenarios", systemImage: "exclamationmark.triangle", description: Text("\(error)\n\nExpected in \(store.directory.path). Set ECHOSENSE_SCENARIOS to another folder."))
            } else {
                HSplitView {
                    ScenarioFilterColumn(store: store, filters: filters, selectedID: selectedID).frame(minWidth: 200, idealWidth: 230, maxWidth: 300)
                        .disabled(isEditing)
                    list.frame(minWidth: 260, idealWidth: 320, maxWidth: 480).disabled(isEditing)
                    detail.frame(minWidth: 520, maxWidth: .infinity)
                }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search scenarios")
        .toolbar {
            ToolbarItem { Button("Run all", systemImage: "arrow.clockwise") { store.reload() }.help("Read the files again and run every scenario") }
        }
        .onChange(of: selectedID) { _, _ in isEditing = editsNextSelection; editsNextSelection = false }
        .onAppear { listFocused = true }
    }

    private var filters: Binding<ScenarioFilters> {
        Binding(
            get: { ScenarioFilters(outcome: ScenarioOutcome(rawValue: outcomeFilter), review: ScenarioReview(rawValue: reviewFilter),
                                   area: areaFilter.isEmpty ? nil : areaFilter, thread: ScenarioThreadState(rawValue: threadFilter),
                                   rule: ruleFilter.isEmpty ? nil : ruleFilter) },
            set: {
                outcomeFilter = $0.outcome?.rawValue ?? ""; reviewFilter = $0.review?.rawValue ?? ""; areaFilter = $0.area ?? ""
                threadFilter = $0.thread?.rawValue ?? ""; ruleFilter = $0.rule ?? ""
            })
    }

    // MARK: List

    /// The groups and scenarios the filters and search let through, in file order.
    private var visible: [(group: String, scenarios: [CompletionScenario])] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filters = filters.wrappedValue
        return store.groups.compactMap { group in
            let items = store.library.scenarios(in: group).filter { scenario in
                store.matches(scenario, filters) && (query.isEmpty
                    || [scenario.id, scenario.title, scenario.sql, scenario.should].contains { $0.lowercased().contains(query) })
            }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private var list: some View {
        let visible = visible
        return VStack(spacing: 0) {
            if visible.isEmpty {
                ContentUnavailableView(filters.wrappedValue == .reviewQueue && search.isEmpty ? "All reviewed" : "Nothing here",
                                       systemImage: filters.wrappedValue == .reviewQueue ? "checkmark.seal" : "line.3.horizontal.decrease",
                                       description: Text(search.isEmpty ? "No scenario matches these filters." : "No scenario matches “\(search)”."))
            } else {
                List(selection: $selectedID) {
                    ForEach(visible, id: \.group) { entry in
                        Section {
                            ForEach(entry.scenarios) { scenario in
                                ScenarioListRow(scenario: scenario, result: store.result(for: scenario.id)).tag(scenario.id)
                                    .draggable(ScenarioDragItem.scenario(scenario.id).text)
                                    .dropDestination(for: String.self) { texts, _ in
                                        if case .rule(let rule)? = ScenarioDragItem.first(in: texts) { store.setFollows(rule, true, scenario: scenario.id) }
                                    }
                                    .contextMenu { ScenarioRowMenu(scenario: scenario, store: store, select: { selectedID = $0 }) }
                            }
                        } header: {
                            HStack { Text(entry.group); Text("\(entry.scenarios.count)").foregroundStyle(ColorTokens.Text.tertiary) }
                        }
                    }
                }
                .listStyle(.inset)
                .focused($listFocused)
                .onKeyPress("y") { answer(.approved); return .handled }
                .onKeyPress("n") { answer(.flagged); return .handled }
            }
            Divider()
            HStack {
                Button("New scenario", systemImage: "plus") { addScenario() }
                Spacer()
                Text("\(visible.reduce(0) { $0 + $1.scenarios.count }) shown").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    .help("Files: \(store.directory.path)")
            }
            .padding(SpacingTokens.xs).controlSize(.small)
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let id = selectedID, store.library.scenario(id: id) != nil {
            ScenarioReviewPane(id: id, store: store, isEditing: $isEditing, answer: answer, select: { selectedID = $0 })
                .id(id)
        } else {
            LabMailEmpty(title: "Select a scenario", symbol: "checklist")
        }
    }

    // MARK: Actions

    /// Records the owner's answer. Right moves on to the next scenario; Wrong stays and puts the
    /// cursor in the note (Return there moves on).
    private func answer(_ review: ScenarioReview) {
        guard let id = selectedID else { return }
        let order = visible.flatMap { $0.scenarios.map(\.id) }
        nextAfterAnswer = order.firstIndex(of: id).flatMap { order.indices.contains($0 + 1) ? order[$0 + 1] : nil }
        store.setReview(review, for: id)
        if review == .approved { goToNext() }
    }

    private func goToNext() {
        let order = visible.flatMap { $0.scenarios.map(\.id) }
        if let id = selectedID, let index = order.firstIndex(of: id) {
            if order.indices.contains(index + 1) { selectedID = order[index + 1] }
        } else if let next = nextAfterAnswer {
            selectedID = next
        }
        nextAfterAnswer = nil
        listFocused = true
    }

    private func addScenario() {
        let id = store.nextID(prefix: "MINE")
        store.update(CompletionScenario(id: id, group: "My scenarios", title: "New scenario", sql: "SELECT * FROM |", review: .approved))
        filters.wrappedValue = ScenarioFilters()
        editsNextSelection = true
        selectedID = id
    }
}
