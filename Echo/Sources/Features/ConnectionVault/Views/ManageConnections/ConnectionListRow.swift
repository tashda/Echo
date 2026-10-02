import SwiftUI

/// Round MC: a connection as a two-line row. The server's mark in its colour, the name, then
/// engine · server:port · database; who signs in and when it was last used on the right.
struct ConnectionListRow: View {
    let connection: SavedConnection
    let name: String
    let signIn: SignInSummary
    let lastUsed: Date?
    let hasDuplicateName: Bool
    let color: Color

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            ServerRailMark(
                monogram: ServerRailMonogram.make(from: name),
                glyph: connection.railGlyph,
                color: color,
                weight: .bold,
                size: ConnectionListRowMetrics.markSize
            )
            .background(color.opacity(ServerAppearanceMetrics.previewTintOpacity), in: Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack(spacing: SpacingTokens.xxs2) {
                    Text(name)
                        .font(TypographyTokens.standard.weight(.semibold))
                        .lineLimit(1)
                    if hasDuplicateName { DuplicateNameDot() }
                }
                HStack(spacing: SpacingTokens.xxs) {
                    // The engine as its symbol only, so the server address gets the room.
                    Image(connection.databaseType.iconName)
                        .help(connection.databaseType.displayName)
                        .accessibilityLabel(connection.databaseType.displayName)
                    ServerAddressText(connection: connection)
                    if !connection.database.isEmpty && connection.databaseType != .sqlite {
                        Text("·").foregroundStyle(ColorTokens.Text.tertiary)
                        Text(connection.database).lineLimit(1)
                    }
                }
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            }

            Spacer(minLength: SpacingTokens.xs)

            VStack(alignment: .trailing, spacing: SpacingTokens.xxxs) {
                SignInLabel(summary: signIn)
                    .font(TypographyTokens.detail)
                LastUsedText(date: lastUsed)
                    .font(TypographyTokens.detail)
            }
        }
        .padding(.vertical, SpacingTokens.xxxs)
        .accessibilityElement(children: .combine)
    }
}

enum ConnectionListRowMetrics {
    static let markSize: CGFloat = 28
}

/// Two connections share this name (ME1): marked, not blocked.
struct DuplicateNameDot: View {
    var body: some View {
        Circle()
            .fill(ColorTokens.Status.warning)
            .frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
            .help("Another connection has this name")
            .accessibilityLabel("Another connection has this name")
    }
}

/// The engine symbol and name, with the server version once Echo has connected.
struct EngineLabel: View {
    let connection: SavedConnection
    var showsVersion = true

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Image(connection.databaseType.iconName)
                .imageScale(.small)
            Text(text).lineLimit(1)
        }
    }

    private var text: String {
        let name = connection.databaseType.shortDisplayName
        guard showsVersion, let version = connection.serverVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty else {
            return name
        }
        return version.localizedCaseInsensitiveContains(name) ? version : "\(name) \(version)"
    }
}

/// host:port, truncated in the middle so both ends stay visible; the engine's default port is
/// dimmed and any other port stands out.
struct ServerAddressText: View {
    let connection: SavedConnection

    var body: some View {
        if connection.databaseType == .sqlite {
            Text(URL(fileURLWithPath: connection.host).lastPathComponent)
                .lineLimit(1)
                .help(connection.host)
        } else {
            let isDefaultPort = connection.port == connection.databaseType.defaultPort
            (Text(connection.host)
                + Text(":\(String(connection.port))")
                    .foregroundStyle(isDefaultPort ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                    .fontWeight(isDefaultPort ? .regular : .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .monospacedDigit()
                .help("\(connection.host):\(String(connection.port))")
        }
    }
}

/// Who signs in, in words, with a symbol for identities and other kinds.
struct SignInLabel: View {
    let summary: SignInSummary

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            if let symbol = summary.systemImage {
                Image(systemName: symbol).imageScale(.small)
            }
            Text(summary.text).lineLimit(1)
        }
        .foregroundStyle(summary.isWarning ? ColorTokens.Status.warning : ColorTokens.Text.secondary)
    }
}

/// "12 min", "3 h", "Yesterday", "4 d", then the date; "Never" when there is no record.
struct LastUsedText: View {
    let date: Date?

    var body: some View {
        Text(Self.text(for: date))
            .foregroundStyle(date == nil ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            .monospacedDigit()
    }

    static func text(for date: Date?, now: Date = Date()) -> String {
        guard let date else { return "Never" }
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min" }
        if seconds < 86_400 { return "\(Int(seconds / 3600)) h" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        if seconds < 7 * 86_400 { return "\(Int(seconds / 86_400)) d" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// Round MC: an identity as a two-line row: name, then kind and who it signs in as; how many
/// connections use it on the right.
struct IdentityListRow: View {
    let identity: SavedIdentity
    let usageCount: Int

    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: ConnectionListRowMetrics.markSize * 0.8))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: ConnectionListRowMetrics.markSize, height: ConnectionListRowMetrics.markSize)
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(identity.name)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .lineLimit(1)
                Text("\(identity.authenticationMethod.displayName) · signs in as \(identity.signInName)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: SpacingTokens.xs)
            Text(usageCount == 0 ? "Not used" : (usageCount == 1 ? "1 connection" : "\(usageCount) connections"))
                .font(TypographyTokens.detail)
                .foregroundStyle(usageCount == 0 ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
        }
        .padding(.vertical, SpacingTokens.xxxs)
    }
}
