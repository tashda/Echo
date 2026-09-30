import EchoSenseScenarios
import SwiftUI

/// Test › Scenarios: every scenario, one by one, with the expected result beside the actual one.
struct ScenariosTestPage: View {
    @State private var store = ScenarioStore.shared
    @AppStorage("lab.scenarios.selected") private var selectedID: String?
    @AppStorage("lab.scenarios.filter") private var filter: Filter = .all
    @State private var search = ""

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", failing = "Failing", known = "Known issues", unchecked = "No expected result", imported = "Not reviewed"
        var id: String { rawValue }
    }

    private func matches(_ scenario: CompletionScenario) -> Bool {
        let result = store.result(for: scenario.id)
        switch filter {
        case .all: break
        case .failing: guard result?.isFailing == true, scenario.knownIssue == nil else { return false }
        case .known: guard scenario.knownIssue != nil else { return false }
        case .unchecked: guard result.map({ !$0.isFailing && !$0.isPass }) == true else { return false }
        case .imported: guard scenario.review == .imported else { return false }
        }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return query.isEmpty || scenario.id.lowercased().contains(query) || scenario.title.lowercased().contains(query)
            || scenario.sql.lowercased().contains(query) || scenario.should.lowercased().contains(query)
    }

    var body: some View {
        Group {
            if let error = store.loadError, store.scenarios.isEmpty {
                ContentUnavailableView("No scenarios", systemImage: "exclamationmark.triangle", description: Text("\(error)\n\nExpected in \(store.directory.path). Set ECHOSENSE_SCENARIOS to another folder."))
            } else {
                HSplitView {
                    list.frame(minWidth: 320, idealWidth: 380, maxWidth: 520)
                    detail.frame(minWidth: 620)
                }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search scenarios")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Show", selection: $filter) { ForEach(Filter.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.inline)
                } label: {
                    Image(systemName: filter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 15)).frame(width: 22, height: 22)
                }
                .menuIndicator(.hidden).help("Show: \(filter.rawValue)")
            }
            ToolbarItem { Button("Run all", systemImage: "play.circle") { store.reload() }.help("Reload the files and run every scenario") }
        }
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: 0) {
            summary.padding(SpacingTokens.sm)
            Divider()
            List(selection: $selectedID) {
                ForEach(store.groups, id: \.self) { group in
                    let items = store.library.scenarios(in: group).filter(matches)
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { scenario in row(scenario).tag(scenario.id) }
                        } header: {
                            HStack { Text(group).fontWeight(.semibold); Text("\(items.count)").foregroundStyle(ColorTokens.Text.tertiary) }.font(TypographyTokens.detail)
                        }
                    }
                }
            }
            .listStyle(.inset)
            Divider()
            HStack {
                Button("New scenario", systemImage: "plus") { addScenario() }
                Spacer()
                Text(store.directory.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1).truncationMode(.head)
            }.padding(SpacingTokens.xs).controlSize(.small)
        }
    }

    private var summary: some View {
        let summary = store.summary
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Scenarios").font(TypographyTokens.title2.weight(.bold))
                Text("\(store.scenarios.count)").foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
            }
            HStack(spacing: 8) {
                chip("\(summary.pass)", "checkmark.circle.fill", ColorTokens.Status.success)
                chip("\(summary.fail)", "xmark.octagon.fill", ColorTokens.Status.error)
                chip("\(summary.known)", "exclamationmark.triangle.fill", ColorTokens.Status.warning)
                chip("\(summary.unchecked)", "questionmark.circle", ColorTokens.Text.secondary)
                Spacer()
            }
            Text("passing · failing · known issues · no expected result yet").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    private func chip(_ text: String, _ symbol: String, _ tint: Color) -> some View {
        Label(text, systemImage: symbol).font(TypographyTokens.standard.weight(.semibold).monospacedDigit()).foregroundStyle(tint)
    }

    private func row(_ scenario: CompletionScenario) -> some View {
        let result = store.result(for: scenario.id)
        let (symbol, tint): (String, Color) = {
            guard let result else { return ("circle", ColorTokens.Text.tertiary) }
            if result.isFailing { return scenario.knownIssue != nil ? ("exclamationmark.triangle.fill", ColorTokens.Status.warning) : ("xmark.octagon.fill", ColorTokens.Status.error) }
            if result.isPass { return (scenario.knownIssue != nil ? "exclamationmark.circle" : "checkmark.circle.fill", scenario.knownIssue != nil ? ColorTokens.Status.warning : ColorTokens.Status.success) }
            return ("questionmark.circle", ColorTokens.Text.tertiary)
        }()
        return HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(scenario.title).lineLimit(1)
                HStack(spacing: 6) {
                    Text(scenario.id).font(.system(size: 10, design: .monospaced)).foregroundStyle(ColorTokens.Text.tertiary)
                    Text(scenario.sql.replacingOccurrences(of: "\n", with: " ")).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                }
            }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let id = selectedID, store.library.scenario(id: id) != nil {
            ScenarioEditorView(
                scenario: Binding(
                    get: { store.library.scenario(id: id) ?? CompletionScenario(id: id, group: "", title: "", sql: "|") },
                    set: { store.update($0) }))
                .id(id)
        } else {
            LabMailEmpty(title: "Select a scenario", symbol: "checklist")
        }
    }

    private func addScenario() {
        let id = store.nextID(prefix: "MINE")
        store.update(CompletionScenario(id: id, group: "My scenarios", title: "New scenario", sql: "SELECT * FROM |", review: .approved))
        selectedID = id
    }
}
