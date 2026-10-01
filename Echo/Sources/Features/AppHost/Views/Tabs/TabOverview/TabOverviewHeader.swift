import SwiftUI

extension TabOverviewView {
    /// The slim header (plan O2): what's open and running, and collapse or expand every group.
    var overviewHeader: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Open Tabs")
                .font(TypographyTokens.headline)
            Text(headerSummary)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .monospacedDigit()
            Spacer(minLength: SpacingTokens.none)
            if !groupedTabs.isEmpty {
                Button("Collapse All") { withAnimation(animation) { collapseAll() } }
                Button("Expand All") { withAnimation(animation) { expandAll() } }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, SpacingTokens.xl)
        .padding(.top, SpacingTokens.md)
    }

    private var headerSummary: String {
        let running = tabs.filter { $0.query?.isExecuting == true }.count
        let count = "\(tabs.count) \(tabs.count == 1 ? "tab" : "tabs")"
        return running > 0 ? "\(count) · \(running) running" : count
    }

    private func collapseAll() {
        collapsedServers = Set(tabs.map { $0.connection.id })
        collapsedDatabases = Set(tabs.map { databaseIdentifier(for: databaseKey(for: $0), serverID: $0.connection.id) })
    }

    private func expandAll() {
        collapsedServers.removeAll()
        collapsedDatabases.removeAll()
    }
}
