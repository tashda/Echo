import SwiftUI

/// Everything across all areas that is waiting for someone, newest need first.
struct LabInboxView: View {
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator

    private let waiting: [LabStatus] = [.newFeedback, .judging, .accepted, .inEcho]

    var body: some View {
        let entries = waiting.map { status in
            (status, LabRegistry.pages.filter { store.status(of: $0) == status && ($0.section != .test && $0.section != .reference) })
        }
        if entries.allSatisfy({ $0.1.isEmpty }) {
            ContentUnavailableView("All caught up", systemImage: "tray",
                                   description: Text("Nothing is waiting for feedback or for the agent."))
        } else {
            List {
                ForEach(entries, id: \.0) { status, pages in
                    if !pages.isEmpty {
                        Section(status.rawValue) {
                            ForEach(pages) { page in
                                Button { navigator.openPage(page.id) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(page.title).font(TypographyTokens.standard.weight(.medium))
                                            Text(LabAreas.area(id: LabAreas.areaID(ofPage: page.id))?.title ?? "No area yet")
                                                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(ColorTokens.Text.tertiary)
                                    }
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
