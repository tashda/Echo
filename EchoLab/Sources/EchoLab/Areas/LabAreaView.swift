import SwiftUI

/// An area's page: Overview (As built) and Rounds, with round pages pushed on top so the
/// sidebar never has to list them.
struct LabAreaView: View {
    let area: LabArea
    @Binding var currentPageID: String?
    @Binding var openRound: String?

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview", rounds = "Rounds"
        var id: String { rawValue }
    }

    @Environment(LabStore.self) private var store
    @State private var tab: Tab = .overview
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch tab {
                case .overview: AsBuiltView(area: area, page: area.asBuilt)
                case .rounds: LabRoundsList(area: area)
                }
            }
            .navigationTitle(area.title)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $tab) {
                        Text("Overview").tag(Tab.overview)
                        Text("Rounds · \(LabAreas.rounds(in: area).count)").tag(Tab.rounds)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationDestination(for: String.self) { id in
                if let page = LabRegistry.page(id: id) { LabPageContainer(page: page) }
            }
        }
        .environment(\.labOpenRound) { id in path.append(id) }
        .onChange(of: path) { _, new in currentPageID = new.last ?? area.asBuiltPageID }
        .onChange(of: openRound) { _, id in consumeOpenRound(id) }
        .onAppear { consumeOpenRound(openRound) }
    }

    private func consumeOpenRound(_ id: String?) {
        guard let id else { return }
        path = [id]
        openRound = nil
    }
}

/// An area's rounds, grouped by where each stands.
struct LabRoundsList: View {
    let area: LabArea
    @Environment(LabStore.self) private var store

    var body: some View {
        let rounds = LabAreas.rounds(in: area)
        if rounds.isEmpty {
            ContentUnavailableView("No rounds yet", systemImage: "clock.arrow.circlepath",
                                   description: Text("Rounds that shape this area will appear here."))
        } else {
            List {
                ForEach(LabStatus.allCases, id: \.self) { status in
                    let items = rounds.filter { store.status(of: $0) == status }
                    if !items.isEmpty {
                        Section(status.rawValue) {
                            ForEach(items) { page in
                                NavigationLink(value: page.id) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(page.title).font(TypographyTokens.standard.weight(.medium))
                                        Text(page.summary).font(TypographyTokens.detail)
                                            .foregroundStyle(ColorTokens.Text.secondary).lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
