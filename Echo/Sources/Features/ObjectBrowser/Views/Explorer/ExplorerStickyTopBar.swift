import SwiftUI
import AppKit
import EchoSense

struct StickyTopBarContent: View {
    @ObservedObject var session: ConnectionSession
    let databaseName: String
    let onTap: () -> Void
    let onRefresh: () -> Void

    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var environmentState: EnvironmentState
    @State private var isHovered = false

    private var progressValue: Double? {
        if case .loading(let value) = session.structureLoadingState {
            return value
        }
        return nil
    }

    private var isUpdating: Bool {
        if case .loading = session.structureLoadingState {
            return true
        }
        return false
    }

    private var updateMessage: String {
        session.structureLoadingMessage ?? "Updating…"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: isUpdating ? 12 : 0) {
                HStack(spacing: 12) {
                    if let logoData = session.connection.logo, let nsImage = NSImage(data: logoData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(session.connection.color.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(session.connection.databaseType.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 13, height: 13)
                                .foregroundStyle(session.connection.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(session.connection.connectionName)
                                .font(TypographyTokens.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if let version = session.connection.serverVersion {
                                Text("•")
                                    .font(TypographyTokens.label.weight(.medium))
                                    .foregroundStyle(.tertiary)
                                Text(version)
                                    .font(TypographyTokens.label.weight(.medium))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }

                        Text("\(session.connection.username)@\(session.connection.host)")
                            .font(TypographyTokens.label.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isHovered {
                        Button(action: {
                            onRefresh()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(TypographyTokens.detail.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }

                    Text(databaseName)
                        .font(TypographyTokens.label.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, SpacingTokens.xs2)
                        .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(ColorTokens.Background.secondary.opacity(0.6))
                            .background(.ultraThinMaterial, in: Capsule())
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(session.connection.color.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: session.connection.color.opacity(0.1), radius: 4, x: 0, y: 2)
                    .contextMenu {
                        if let structure = session.databaseStructure {
                            ForEach(structure.databases, id: \.name) { database in
                                Button {
                                    Task { @MainActor in
                                        await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                                    }
                                } label: {
                                    Label(database.name, systemImage: "database")
                                }
                            }
                        }
                    }
            }
                if isUpdating {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: min(max(progressValue ?? 0, 0), 1), total: 1)
                            .progressViewStyle(.linear)
                            .tint(session.connection.color)
                        Text(updateMessage)
                            .font(TypographyTokens.label.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, SpacingTokens.sm2)
            .padding(.vertical, isUpdating ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        projectStore.globalSettings.accentColorSource == .connection ?
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ColorTokens.Background.secondary.opacity(0.85),
                                session.connection.color.opacity(0.08)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ColorTokens.Background.secondary.opacity(0.85),
                                ColorTokens.Background.secondary.opacity(0.85)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        projectStore.globalSettings.accentColorSource == .connection ?
                        session.connection.color.opacity(0.15) :
                        Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .animation(.easeInOut(duration: 0.2), value: isUpdating)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.top, SpacingTokens.md2)
        .padding(.bottom, SpacingTokens.xs)
    }
}
