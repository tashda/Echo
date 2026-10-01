import EchoSenseScenarios
import SwiftUI

/// Test › (a domain): every scenario of one kind, the expected lines beside the actual ones.
struct DomainScenariosPage: View {
    let domain: ScenarioDomain
    @State private var store = DomainScenarioStore.shared
    @State private var search = ""
    @State private var selectedID: String?

    private func matches(_ scenario: DomainScenario) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return query.isEmpty || scenario.id.lowercased().contains(query) || scenario.title.lowercased().contains(query)
            || scenario.input.lowercased().contains(query)
    }

    var body: some View {
        Group {
            if let error = store.loadError, store.library.scenarios.isEmpty {
                ContentUnavailableView("No scenarios", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                HSplitView {
                    list.frame(minWidth: 300, idealWidth: 360, maxWidth: 480)
                    detail.frame(minWidth: 560)
                }
            }
        }
        .labToolbarSearch(text: $search, prompt: "Search scenarios")
        .toolbar { ToolbarItem { Button("Run all", systemImage: "play.circle") { store.reload() }.help("Reload the files and run every scenario") } }
        .onAppear { if selectedID == nil { selectedID = store.scenarios(in: domain.id).first?.id } }
    }

    // MARK: List

    private var list: some View {
        let summary = store.summary(domain: domain.id)
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(domain.title).font(TypographyTokens.title2.weight(.bold))
                Text(domain.summary).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                HStack(spacing: 10) {
                    Label("\(summary.pass)", systemImage: "checkmark.circle.fill").foregroundStyle(ColorTokens.Status.success)
                    Label("\(summary.fail)", systemImage: "xmark.octagon.fill").foregroundStyle(ColorTokens.Status.error)
                    Label("\(summary.known)", systemImage: "exclamationmark.triangle.fill").foregroundStyle(ColorTokens.Status.warning)
                    Label("\(summary.unchecked)", systemImage: "questionmark.circle").foregroundStyle(ColorTokens.Text.secondary)
                }
                .font(TypographyTokens.standard.weight(.semibold).monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(SpacingTokens.sm)
            Divider()
            List(selection: $selectedID) {
                ForEach(store.library.groups(in: domain.id), id: \.self) { group in
                    let items = store.scenarios(in: domain.id).filter { $0.group == group && matches($0) }
                    if !items.isEmpty {
                        Section(group) { ForEach(items) { row($0).tag($0.id) } }
                    }
                }
            }
            .listStyle(.inset)
            Divider()
            HStack {
                Button("New scenario", systemImage: "plus") { addScenario() }
                Spacer()
            }.padding(SpacingTokens.xs).controlSize(.small)
        }
    }

    private func row(_ scenario: DomainScenario) -> some View {
        let verdict = store.result(for: scenario.id)?.verdict
        let (symbol, tint): (String, Color) = switch verdict {
        case .pass: ("checkmark.circle.fill", ColorTokens.Status.success)
        case .fail: ("xmark.octagon.fill", ColorTokens.Status.error)
        case .knownIssue: ("exclamationmark.triangle.fill", ColorTokens.Status.warning)
        default: ("questionmark.circle", ColorTokens.Text.tertiary)
        }
        return HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(scenario.title).lineLimit(1)
                Text(scenario.id).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let id = selectedID, store.scenario(id: id) != nil {
            DomainScenarioEditor(
                domain: domain,
                scenario: Binding(
                    get: { store.scenario(id: id) ?? DomainScenario(id: id, domain: domain.id, group: "", title: "", should: "", input: "") },
                    set: { store.update($0) }),
                result: store.result(for: id),
                onDelete: { store.delete(id: id); selectedID = nil })
            .id(id)
        } else {
            LabMailEmpty(title: "Select a scenario", symbol: "checklist")
        }
    }

    private func addScenario() {
        let prefix = "MINE-" + domain.id.prefix(3).uppercased()
        let id = store.library.nextID(prefix: prefix)
        store.update(DomainScenario(id: id, domain: domain.id, group: "My scenarios", title: "New scenario", should: "", input: ""))
        selectedID = id
    }
}
