import SwiftUI

struct DatabaseSidebarView: View {
    @Binding var selectedConnectionID: UUID?
    let icon: String
    let title: String
    let description: String
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @State private var selectedSection: Section = .agent

    enum Section: String, CaseIterable, Identifiable {
        case agent = "Agent"
        case security = "Security"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, SpacingTokens.md)
                .padding(.top, SpacingTokens.sm)
                .padding(.bottom, SpacingTokens.xs)
            
            Divider()
            
            HStack {
                Picker("", selection: $selectedSection) {
                    ForEach(Section.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(SpacingTokens.xs)

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
    
    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(title)
                .font(TypographyTokens.headline)
            Text(description)
                .font(TypographyTokens.footnote)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
