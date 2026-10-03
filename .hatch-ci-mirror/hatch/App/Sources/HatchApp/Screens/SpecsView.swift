import SwiftUI
import AppKit
import HatchCore

/// Specs by area with IDs and linked tickets (decisions L3, L5, N1).
struct SpecsView: View {
    @EnvironmentObject var state: AppState

    @State private var query = ""
    @State private var selectedArea: String? = nil
    @State private var selectedCode: String?

    private let allAreas = "All areas"

    // MARK: Data

    private var projectId: Int? { state.hxProject?.id }

    private var items: [SpecItem] {
        guard let pid = projectId else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var list: [SpecItem]
        if trimmed.isEmpty {
            list = (try? state.store.specItems(projectId: pid)) ?? []
        } else {
            list = (try? state.store.searchSpec(projectId: pid, query: trimmed, limit: 100)) ?? []
        }
        if let area = selectedArea { list = list.filter { ($0.area ?? "General") == area } }
        return list
    }

    private var areaNames: [String] {
        guard let pid = projectId else { return [] }
        let all = (try? state.store.specItems(projectId: pid)) ?? []
        var names: [String] = []
        for i in all {
            let n = i.area ?? "General"
            if !names.contains(n) { names.append(n) }
        }
        return names.sorted()
    }

    private func count(in area: String) -> Int {
        guard let pid = projectId else { return 0 }
        let all = (try? state.store.specItems(projectId: pid)) ?? []
        return all.filter { ($0.area ?? "General") == area }.count
    }

    private var selectedItem: SpecItem? {
        guard let code = selectedCode else { return nil }
        return items.first { $0.code == code }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if projectId == nil {
                ContentUnavailableView("No project", systemImage: "doc.text", description: Text("Add a project to see its Spec."))
            } else if areaNames.isEmpty {
                emptyState
            } else {
                HSplitView {
                    areaList.frame(minWidth: 160, idealWidth: 180, maxWidth: 240)
                    itemList.frame(minWidth: 300)
                    detail.frame(minWidth: 280, idealWidth: 340)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HXHeader(title: "Specs", subtitle: state.hxProject?.name ?? "")
            Spacer()
            TextField("Search the Spec", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            Button { createBlueprint() } label: { Label("Create Spec app blueprint", systemImage: "wand.and.stars") }
                .buttonStyle(.glass)
                .help("Creates a ticket for an agent to scaffold the project's Spec app from its area index.")
        }
        .padding(12)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("The Spec is empty", systemImage: "doc.text")
        } description: {
            Text("Spec items are read from .hatch/spec/*.md in the app repo when Hatch syncs the project. Add one file per area.")
        }
        .frame(maxHeight: .infinity)
    }

    private var areaList: some View {
        List(selection: $selectedArea) {
            Label(allAreas, systemImage: "square.grid.2x2").tag(String?.none)
            ForEach(areaNames, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Text("\(count(in: name))").foregroundStyle(.secondary).font(.caption).monospacedDigit()
                }
                .tag(String?.some(name))
            }
        }
    }

    private var itemList: some View {
        List(selection: $selectedCode) {
            ForEach(items, id: \.code) { item in
                itemRow(item).tag(String?.some(item.code))
            }
        }
    }

    private func itemRow(_ item: SpecItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(item.code).font(.callout.monospaced()).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(item.text).lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let item = selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.code).font(.title3.monospaced())
                    Text(item.text).textSelection(.enabled)
                    if let area = item.area { Text("Area: \(area)").font(.caption).foregroundStyle(.secondary) }
                    if let source = item.source { Text("Source: \(source)").font(.caption).foregroundStyle(.secondary) }
                    specAppRow(item)
                    linkedTickets(item)
                    linkedDecisions(item)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Pick a Spec item", systemImage: "doc.text.magnifyingglass", description: Text("See the tickets and decisions that touch it."))
        }
    }

    private func specAppRow(_ item: SpecItem) -> some View {
        let path = state.hxSetting("spec_app_path")
        return VStack(alignment: .leading, spacing: 4) {
            Button { openSpecApp(path: path, code: item.code) } label: { Label("Open in Spec app", systemImage: "arrow.up.forward.app") }
                .buttonStyle(.glass)
                .disabled(path == nil)
            if path == nil {
                Text("No Spec app is set for this project. Set its path in Settings, or create the blueprint first.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func linkedTickets(_ item: SpecItem) -> some View {
        let found = (try? state.store.tickets(TicketFilter(projectId: projectId, text: item.code, limit: 20))) ?? []
        return VStack(alignment: .leading, spacing: 4) {
            Text("Tickets").font(.headline)
            if found.isEmpty { Text("No ticket mentions this item.").font(.callout).foregroundStyle(.secondary) }
            ForEach(found) { t in
                Button { state.open(t) } label: {
                    HStack(spacing: 6) {
                        Text(t.displayNumber).foregroundStyle(.secondary)
                        Text(t.title).lineLimit(1)
                        HXStatusChip(status: t.status)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func linkedDecisions(_ item: SpecItem) -> some View {
        let all = (try? state.store.decisions(projectId: projectId)) ?? []
        let matching = all.filter { $0.specCodes.contains(item.code) }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Decisions").font(.headline)
            if matching.isEmpty { Text("No decision changed this item.").font(.callout).foregroundStyle(.secondary) }
            ForEach(Array(matching.enumerated()), id: \.offset) { _, d in
                Button { state.open(d.ticket) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(d.ticket.displayNumber) \(d.ticket.title)").lineLimit(1)
                        Text(d.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Actions

    private func openSpecApp(path: String?, code: String) {
        guard let path else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--spec", code]
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config, completionHandler: nil)
    }

    private func createBlueprint() {
        guard let project = state.hxProject else { return }
        let areas = (project.config?.areas ?? []).map { $0.name }.joined(separator: ", ")
        let body = """
        What: scaffold a Spec app for \(project.name), built the same way as the Stage app.
        Why: each element of the app should be viewable as a live specimen next to what has been decided about it (decision L5).
        Scope: one page per area from the area index (\(areas.isEmpty ? "no areas yet" : areas)), each listing its Spec items and a live specimen.
        Constraints: the app opens a given item with --spec <code>. No project code goes into Hatch.
        """
        let created: Ticket? = state.perform("Create blueprint ticket") {
            try state.store.createTicket(projectId: project.id, type: .tweak, title: "Create the Spec app blueprint for \(project.name)", body: body)
        }
        if let created { state.open(created) }
    }
}
