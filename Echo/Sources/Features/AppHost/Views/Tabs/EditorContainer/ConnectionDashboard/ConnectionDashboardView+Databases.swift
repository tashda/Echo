import SwiftUI

struct ConnectionDashboardDatabases: View {
    @Bindable var session: ConnectionSession
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.echoMotion) private var motion

    @State private var showAll = false

    private var databases: [DatabaseInfo] {
        session.databaseStructure?.databases ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            DashboardSectionLabel(title: "New query in")

            switch session.structureLoadingState {
            case .loading:
                loadingState
            case .failed(let message):
                failedState(message)
            default:
                if databases.isEmpty {
                    emptyState
                } else {
                    databaseGrid
                }
            }
        }
    }

    // MARK: - Grid

    private var visibleDatabases: [DatabaseInfo] {
        if showAll || databases.count <= 9 {
            return databases
        }
        return Array(databases.prefix(9))
    }

    @ViewBuilder
    private var databaseGrid: some View {
        DashboardCard {
            ForEach(visibleDatabases) { db in
                DashboardDatabaseRow(
                    name: db.name,
                    stateDescription: db.stateDescription,
                    isSelected: db.name == session.sidebarFocusedDatabase
                ) {
                    environmentState.openQueryTab(for: session, database: db.name)
                }
            }
        }

        if databases.count > 9, !showAll {
            Button {
                withAnimation(motion.standard) { showAll = true }
            } label: {
                Text("Show all \(databases.count) databases")
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.accent)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, SpacingTokens.xxs)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        TabInitializingPlaceholder(
            icon: "cylinder",
            title: "Loading Databases",
            subtitle: "Fetching database list..."
        )
    }

    private func failedState(_ message: String?) -> some View {
        Text(message ?? "Failed to load databases")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, SpacingTokens.sm)
    }

    private var emptyState: some View {
        Text("No databases found")
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, SpacingTokens.sm)
    }
}

// MARK: - Database Row

/// A database on the page's "New query in" card: a click opens a query tab in it.
struct DashboardDatabaseRow: View {
    let name: String
    let stateDescription: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DashboardCardRow(isSelected: isSelected) {
                Image(systemName: "cylinder")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.accent)
                    .frame(width: LayoutTokens.Welcome.monogramWidth)

                Text(name)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let state = stateDescription, state.lowercased() != "online" {
                    Text(state)
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Status.warning)
                }

                Spacer(minLength: SpacingTokens.xs)

                Image(systemName: "chevron.right")
                    .font(TypographyTokens.compact.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .buttonStyle(.plain)
        .help("New query in \(name)")
    }
}
