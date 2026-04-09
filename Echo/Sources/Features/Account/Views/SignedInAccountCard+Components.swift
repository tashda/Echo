import SwiftUI

extension SignedInAccountCard {

    // MARK: - Sync Summary (inline, one line)

    @ViewBuilder
    var syncSummary: some View {
        if let engine = syncEngine {
            HStack(spacing: 4) {
                switch engine.status {
                case .idle:
                    if let lastSync = engine.lastSyncedAt {
                        Image(systemName: "checkmark.icloud")
                            .foregroundStyle(ColorTokens.Status.success)
                        Text("Synced \(lastSync, format: .relative(presentation: .named))")
                    } else {
                        Image(systemName: "icloud")
                            .foregroundStyle(ColorTokens.Text.tertiary)
                        Text("Sync available")
                    }
                case .syncing:
                    ProgressView()
                        .controlSize(.mini)
                    Text("Syncing…")
                case .error:
                    Image(systemName: "exclamationmark.icloud")
                        .foregroundStyle(ColorTokens.Status.error)
                    Text("Sync error — tap to retry")
                case .offline:
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text("Offline")
                case .disabled:
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text("Sync disabled")
                }
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.tertiary)
        }
    }

    @ViewBuilder
    func syncRefreshButton(_ engine: SyncEngine) -> some View {
        Button {
            Task(name: "account-card-sync-refresh") {
                await engine.syncNow()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(isRefreshHovered ? 0.08 : 0))

                Group {
                    if engine.status == .syncing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.medium)
                    }
                }
                .foregroundStyle(ColorTokens.Text.primary)
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .help(engine.status == .syncing ? "Syncing" : "Sync Now")
        .disabled(engine.status == .syncing || engine.status == .disabled)
        .onHover { isRefreshHovered = $0 }
    }

    // MARK: - Avatar

    @ViewBuilder
    var accountAvatar: some View {
        if let avatarURL = authState.currentUser?.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                default:
                    initialsAvatar
                }
            }
        } else {
            initialsAvatar
        }
    }

    var initialsAvatar: some View {
        ZStack {
            Circle()
                .fill(.quaternary)
                .frame(width: 48, height: 48)

            Text(avatarInitials)
                .font(TypographyTokens.statNumber)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    var avatarInitials: String {
        let name = authState.currentUser?.displayName
            ?? authState.currentUser?.email
            ?? "U"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
