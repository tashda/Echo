import EchoSenseScenarios
import SwiftUI

/// Test › Scenarios, laid out like Mail: filters with counts on the left, the scenarios in the middle
/// (each says what is wrong in a few words), and the one being judged on the right. Y and N answer
/// "is this what should happen?" and move on; ↑ and ↓ move through the list.
struct ScenariosTestPage: View {
    @State private var store = ScenarioStore.shared
    @AppStorage("lab.scenarios.selected") private var selectedID: String?
    @AppStorage("lab.scenarios.show") private var filter: ScenarioFilter = .outcome(.wrong)
    @State private var search = ""
    @State private var isEditing = false
    /// Set when a new scenario is selected so it opens in the editor.
    @State private var editsNextSelection = false

    var body: some View {
        Group {
            if let error = store.loadError, store.scenarios.isEmpty {
                ContentUnavailableView("No scenarios", systemImage: "exclamationmark.triangle", description: Text("\(error)\n\nExpected in \(store.directory.path). Set ECHOSENSE_SCENARIOS to another folder."))
            } else {
                HSplitView {
                    ScenarioFilterColumn(store: store, filter: $filter).frame(minWidth: 190, idealWidth: 220, maxWidth: 300)
                    list.frame(minWidth: 260, idealWidth: 320, maxWidth: 480)
                    detail.frame(minWidth: 520, maxWidth: .infinity)
                }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search scenarios")
        .toolbar {
            ToolbarItem { Button("Run all", systemImage: "arrow.clockwise") { store.reload() }.help("Read the files again and run every scenario") }
        }
        .onChange(of: selectedID) { _, _ in isEditing = editsNextSelection; editsNextSelection = false }
    }

    // MARK: List

    /// The groups and scenarios the filter and search let through, in file order.
    private var visible: [(group: String, scenarios: [CompletionScenario])] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return store.groups.compactMap { group in
            let items = store.library.scenarios(in: group).filter { scenario in
                store.matches(scenario, filter: filter) && (query.isEmpty
                    || [scenario.id, scenario.title, scenario.sql, scenario.should].contains { $0.lowercased().contains(query) })
            }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private var list: some View {
        let visible = visible
        return VStack(spacing: 0) {
            if visible.isEmpty {
                ContentUnavailableView("Nothing here", systemImage: "line.3.horizontal.decrease",
                                       description: Text(search.isEmpty ? "No scenario matches this filter." : "No scenario matches “\(search)”."))
            } else {
                List(selection: $selectedID) {
                    ForEach(visible, id: \.group) { entry in
                        Section {
                            ForEach(entry.scenarios) { scenario in
                                ScenarioListRow(scenario: scenario, result: store.result(for: scenario.id)).tag(scenario.id)
                            }
                        } header: {
                            HStack { Text(entry.group); Text("\(entry.scenarios.count)").foregroundStyle(ColorTokens.Text.tertiary) }
                        }
                    }
                }
                .listStyle(.inset)
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

    /// Records the owner's answer. "Right" moves on to the next scenario in the list; "Wrong" stays,
    /// so the note for the agent can be written.
    private func answer(_ review: ScenarioReview) {
        guard let id = selectedID else { return }
        let order = visible.flatMap { $0.scenarios.map(\.id) }
        let next = order.firstIndex(of: id).flatMap { order.indices.contains($0 + 1) ? order[$0 + 1] : nil }
        store.setReview(review, for: id)
        if review == .approved, let next { selectedID = next }
    }

    private func addScenario() {
        let id = store.nextID(prefix: "MINE")
        store.update(CompletionScenario(id: id, group: "My scenarios", title: "New scenario", sql: "SELECT * FROM |", review: .approved))
        filter = .all
        editsNextSelection = true
        selectedID = id
    }
}
