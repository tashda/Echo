import SwiftUI

extension TabOverviewView {
    var overviewControls: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    collapseAll()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.down.right.fill")
                    Text("Collapse All")
                }
                .font(TypographyTokens.standard.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
            )

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandAll()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text("Expand All")
                }
                .font(TypographyTokens.standard.weight(.medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.sm)
            .padding(.vertical, SpacingTokens.xxs2)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.xl2)
        .padding(.bottom, SpacingTokens.xxs)
        .frame(maxWidth: .infinity)
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
