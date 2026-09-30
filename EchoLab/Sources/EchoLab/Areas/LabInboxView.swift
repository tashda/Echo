import SwiftUI

/// Everything across all areas that is waiting for someone, newest need first.
struct LabInboxView: View {
    @Environment(LabStore.self) private var store
    let open: (String) -> Void

    private let waiting: [LabStatus] = [.newFeedback, .judging, .accepted, .inEcho]

    var body: some View {
        let entries = waiting.map { status in
            (status, LabRegistry.pages.filter { store.status(of: $0) == status && LabAreas.areaID(ofPage: $0.id) != nil })
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
                                Button { open(page.id) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(page.title).font(TypographyTokens.standard.weight(.medium))
                                            Text(LabAreas.area(id: LabAreas.areaID(ofPage: page.id))?.title ?? "")
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
            .navigationTitle("Inbox")
        }
    }
}
