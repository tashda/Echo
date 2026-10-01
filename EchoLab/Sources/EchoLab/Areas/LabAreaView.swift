import SwiftUI

/// An area's page. It has a header with the Overview, Spec and Rounds switcher (in the page,
/// not the toolbar, so it can never appear twice); a round opened inside the area replaces it
/// and Back in the toolbar returns to where you were.
struct LabAreaView: View {
    let area: LabArea
    let location: LabLocation

    @Environment(LabNavigator.self) private var navigator
    @Environment(LabStore.self) private var store

    var body: some View {
        if let roundID = location.round, let page = LabRegistry.page(id: roundID) {
            LabPageContainer(page: page)
        } else {
            VStack(spacing: 0) {
                header
                Divider()
                content
            }
        }
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.md) {
            Label(area.title, systemImage: area.symbol).font(TypographyTokens.title3.weight(.semibold))
            Spacer()
            Picker("View", selection: Binding(get: { location.tab }, set: { navigator.setTab($0) })) {
                Text("Overview").tag(LabAreaTab.overview)
                Text("Rounds · \(LabAreas.rounds(in: area).count)").tag(LabAreaTab.rounds)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.xs)
    }

    @ViewBuilder
    private var content: some View {
        switch location.tab {
        case .overview: AsBuiltView(area: area, page: area.asBuilt)
        case .spec: AsBuiltView(area: area, page: area.asBuilt)
        case .rounds: LabRoundsList(area: area)
        }
    }
}

/// An area's rounds, grouped by where each stands.
struct LabRoundsList: View {
    let area: LabArea
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator

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
                        Section(status.title) {
                            ForEach(items) { page in
                                Button { navigator.openPage(page.id) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(page.title).font(TypographyTokens.standard.weight(.medium))
                                        Text(page.summary).font(TypographyTokens.detail)
                                            .foregroundStyle(ColorTokens.Text.secondary).lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}
