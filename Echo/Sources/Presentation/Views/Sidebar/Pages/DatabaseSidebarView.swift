import SwiftUI

struct DatabaseSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    let icon: String
    let title: String
    let description: String
    @State private var selectedSection: Section = .agent

    enum Section: String, CaseIterable, Identifiable {
        case agent = "Agent"
        case security = "Security"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $selectedSection) {
                    ForEach(Section.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(8)

            Group {
                switch selectedSection {
                case .agent:
                    AgentSidebarView(selectedConnectionID: $selectedConnectionID)
                case .security:
                    SecuritySidebarView(selectedConnectionID: $selectedConnectionID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
