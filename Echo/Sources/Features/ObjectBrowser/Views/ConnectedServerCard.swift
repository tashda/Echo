import SwiftUI
import AppKit
import EchoSense

@MainActor
final class ExplorerDebugLogState {
    static let shared = ExplorerDebugLogState()
    var lastDatabaseBySession: [UUID: String] = [:]
}

struct ConnectedServerCard: View {
    let session: ConnectionSession
    let isSelected: Bool
    @Binding var isExpanded: Bool
    let showCurrentDatabase: Bool
    let onSelectServer: () -> Void
    let onPickDatabase: (String) -> Void

    @EnvironmentObject private var environmentState: EnvironmentState
    @State private var isHovered = false

    private var availableDatabases: [DatabaseInfo] {
        if let structure = session.databaseStructure {
            return structure.databases
        }
        if let cached = session.connection.cachedStructure {
            return cached.databases
        }
        return []
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded, !availableDatabases.isEmpty {
                Divider()
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.top, SpacingTokens.xxs2)

                ScrollView {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                        ForEach(availableDatabases) { database in
                            CompactDatabaseCard(
                                database: database,
                                isSelected: database.name == session.selectedDatabaseName,
                                serverColor: session.connection.color,
                                onSelect: {
                                    onPickDatabase(database.name)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.sm)
                }
                .frame(maxHeight: 160)
                .scrollIndicators(.hidden)
            }
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(isHovered || isExpanded ? 0.14 : 0.05), radius: isExpanded ? 12 : 6, x: 0, y: isExpanded ? 8 : 3)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isExpanded)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                icon

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.connection.connectionName)
                        .font(TypographyTokens.standard.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(session.connection.username)@\(session.connection.host)")
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if showCurrentDatabase, let database = session.selectedDatabaseName {
                    Text(database)
                        .font(TypographyTokens.detail.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, 3)
                        .background(session.connection.color.opacity(0.18), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(session.connection.color.opacity(0.35), lineWidth: 0.6)
                        )
                        .shadow(color: session.connection.color.opacity(0.2), radius: 4, x: 0, y: 2)
                }

                Image(systemName: "chevron.down")
                    .font(TypographyTokens.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, SpacingTokens.sm2)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }
            .onTapGesture(count: 2) {
                onSelectServer()
            }
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(session.connection.color.opacity(0.18))
                .frame(width: 32, height: 32)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(session.connection.color.opacity(0.35), lineWidth: 1)
            Image(session.connection.databaseType.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)
                .foregroundStyle(session.connection.color)
        }
        .shadow(color: session.connection.color.opacity(0.15), radius: 2, x: 0, y: 1)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected ? session.connection.color.opacity(0.18) : Color.primary.opacity(isHovered ? 0.07 : 0.04)
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? session.connection.color.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 0.9)
    }
}
