import SwiftUI

struct ConnectionDashboardDatabases: View {
    @Bindable var session: ConnectionSession
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showAll = false

    private var databases: [DatabaseInfo] {
        session.databaseStructure?.databases ?? []
    }

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.xs),
        GridItem(.flexible(), spacing: SpacingTokens.xs),
        GridItem(.flexible(), spacing: SpacingTokens.xs)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            DashboardSectionLabel(title: "New Query")

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
        LazyVGrid(columns: columns, spacing: SpacingTokens.xs) {
            ForEach(visibleDatabases) { db in
                DashboardDatabaseCard(
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
                withAnimation(.easeInOut(duration: 0.2)) { showAll = true }
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

// MARK: - Database Card

struct DashboardDatabaseCard: View {
    let name: String
    let stateDescription: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "cylinder")
                    .font(TypographyTokens.prominent)
                    .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.Text.secondary)

                Text(name)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let state = stateDescription, state.lowercased() != "online" {
                    Text(state)
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Status.warning)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sm)
            .padding(.horizontal, SpacingTokens.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? ColorTokens.Surface.selectedBorder : .clear, lineWidth: 1)
        )
    }

    private var cardFill: Color {
        if isSelected {
            return ColorTokens.Surface.selected
        }
        return isHovered ? ColorTokens.Surface.hover : ColorTokens.Surface.rest
    }
}
