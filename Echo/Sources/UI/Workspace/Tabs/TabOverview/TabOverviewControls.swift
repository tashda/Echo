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
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
                .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08))
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 4)
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
