import SwiftUI

// MARK: - ManageConnectionsView Empty States

extension ManageConnectionsView {

    @ViewBuilder
    func emptyState(for section: ManageSection) -> some View {
        globalEmptyState(for: section)
    }

    /// Empty state when the project has no items at all for this section.
    @ViewBuilder
    private func globalEmptyState(for section: ManageSection) -> some View {
        ContentUnavailableView {
            Label(section.emptyTitle, systemImage: section == .connections
                  ? "externaldrive"
                  : "person.crop.circle")
        } description: {
            Text(section.emptyMessage)
        } actions: {
            Button {
                handlePrimaryAdd(for: section)
            } label: {
                Text(section.emptyActionTitle)
            }
        }
    }
}
