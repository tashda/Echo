import SwiftUI

/// SwiftUI view for the database breadcrumb popover.
///
/// Displays a filter field, list of databases with selection checkmarks,
/// and a refresh action. Shown inside an `NSPopover` via `NSHostingController`
/// from `BreadcrumbBarView`.
struct DatabasePopoverView: View {
    let connectionStore: ConnectionStore
    let environmentState: EnvironmentState
    let dismiss: () -> Void

    @State private var filter = ""
    @State private var databases: [DatabaseInfo] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            databaseList
            Divider()
            refreshFooter
        }
        .frame(width: 240)
        .frame(minHeight: 120, maxHeight: 380)
        .background(.clear)
        .task { await loadDatabases() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("Databases")
                .font(TypographyTokens.standard.weight(.semibold))

            TextField("Search databases\u{2026}", text: $filter)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.top, SpacingTokens.md)
        .padding(.bottom, SpacingTokens.xs)
    }

    // MARK: - List

    private var databaseList: some View {
        Group {
            if isLoading && databases.isEmpty {
                ContentUnavailableView {
                    ProgressView()
                        .controlSize(.small)
                } description: {
                    Text("Loading databases\u{2026}")
                        .font(TypographyTokens.detail)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else if filteredDatabases.isEmpty && !databases.isEmpty {
                ContentUnavailableView {
                    Text("No matches found")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                List(filteredDatabases) { db in
                    databaseRow(db)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    @ViewBuilder
    private func databaseRow(_ db: DatabaseInfo) -> some View {
        let isSelected = sidebarFocusedDatabase == db.name

        Button {
            selectDatabase(db)
        } label: {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "cylinder")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(width: 14)

                Text(db.name)
                    .font(TypographyTokens.standard)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(TypographyTokens.label.weight(.semibold))
                        .foregroundStyle(ColorTokens.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? ColorTokens.accent.opacity(0.1) : Color.clear)
    }

    // MARK: - Footer

    private var refreshFooter: some View {
        Button {
            Task { await refreshDatabases() }
        } label: {
            Label("Refresh List", systemImage: "arrow.clockwise")
                .font(TypographyTokens.detail)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data

    private var filteredDatabases: [DatabaseInfo] {
        guard !filter.isEmpty else { return databases }
        return databases.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    private var sidebarFocusedDatabase: String? {
        guard let id = connectionStore.selectedConnectionID else { return nil }
        return environmentState.sessionGroup.sessionForConnection(id)?.sidebarFocusedDatabase
    }

    private func loadDatabases() async {
        guard let connectionID = connectionStore.selectedConnectionID,
              let session = environmentState.sessionGroup.sessionForConnection(connectionID) else {
            return
        }

        if let structure = session.databaseStructure {
            databases = structure.databases
        } else {
            isLoading = true
            await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
            if let structure = session.databaseStructure {
                databases = structure.databases
            }
            isLoading = false
        }
    }

    private func refreshDatabases() async {
        guard let connectionID = connectionStore.selectedConnectionID else { return }
        isLoading = true
        await environmentState.refreshDatabaseStructure(for: connectionID, scope: .full)
        if let session = environmentState.sessionGroup.sessionForConnection(connectionID),
           let structure = session.databaseStructure {
            databases = structure.databases
        }
        isLoading = false
    }

    private func selectDatabase(_ db: DatabaseInfo) {
        guard let connectionID = connectionStore.selectedConnectionID,
              let session = environmentState.sessionGroup.sessionForConnection(connectionID) else { return }
        Task {
            await environmentState.loadSchemaForDatabase(db.name, connectionSession: session)
        }
        dismiss()
    }
}
