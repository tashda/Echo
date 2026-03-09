import SwiftUI
import AppKit

struct SavedConnectionExplorerRow: View {
    let connection: SavedConnection
    let isConnecting: Bool
    let onConnect: () -> Void

    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @State private var isHovered = false

    private var displayName: String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private var accentColor: Color {
        projectStore.globalSettings.accentColorSource == .connection ? connection.color : Color.accentColor
    }

    private var isAlreadyConnected: Bool {
        environmentState.sessionCoordinator.sessionForConnection(connection.id) != nil
    }

    var body: some View {
        Button {
            onConnect()
        } label: {
            HStack(spacing: 10) {
                connectionIcon
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(TypographyTokens.standard.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(connection.host)
                        .font(TypographyTokens.label)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isConnecting {
                    ProgressView()
                        .controlSize(.mini)
                } else if isAlreadyConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(TypographyTokens.standard)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .background(rowBackground)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
    }

    @ViewBuilder
    private var connectionIcon: some View {
        if let logoData = connection.logo, let nsImage = NSImage(data: logoData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accentColor.opacity(0.15))
                Image(connection.databaseType.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 10, height: 10)
                    .foregroundStyle(accentColor)
            }
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        let base = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if isHovered {
            base
                .fill(accentColor.opacity(0.1))
                .overlay(base.stroke(accentColor.opacity(0.25), lineWidth: 0.8))
        } else {
            Color.clear
        }
    }
}
