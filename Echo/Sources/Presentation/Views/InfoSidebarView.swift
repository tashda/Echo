import SwiftUI

struct InfoSidebarView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionSection
                if let session = appModel.sessionManager.activeSession {
                    sessionSection(session)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private var connectionSection: some View {
        InspectorSectionCard(title: "Connection") {
            if let connection = appModel.selectedConnection {
                InspectorInfoRow(label: "Name", value: connection.connectionName)
                InspectorInfoRow(label: "Database", value: connection.database.isEmpty ? "Not selected" : connection.database)
                InspectorInfoRow(label: "Host", value: connection.host)
                InspectorInfoRow(label: "User", value: connection.username)
            } else {
                InspectorEmptyRow(message: "No connection selected")
            }
        }
    }

    @ViewBuilder
    private func sessionSection(_ session: ConnectionSession) -> some View {
        InspectorSectionCard(title: "Session") {
            InspectorInfoRow(label: "Active Database", value: session.selectedDatabaseName ?? "None")
            InspectorInfoRow(
                label: "Last Activity",
                value: session.lastActivity.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }
}

private struct InspectorSectionCard<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(0.6)
                .foregroundStyle(titleColor)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        themeManager.activeTheme.windowBackground.color.opacity(themeManager.activePaletteTone == .dark ? 0.55 : 0.75),
                        themeManager.activeTheme.surfaceBackground.color.opacity(themeManager.activePaletteTone == .dark ? 0.65 : 0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(themeManager.accentColor.opacity(0.12), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var titleColor: Color {
        themeManager.accentColor.opacity(themeManager.activePaletteTone == .dark ? 0.8 : 0.7)
    }
}

private struct InspectorInfoRow: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(themeManager.surfaceForegroundColor.opacity(0.55))

            Text(value)
                .font(.callout.weight(.medium))
                .foregroundStyle(themeManager.surfaceForegroundColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspectorEmptyRow: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(themeManager.surfaceForegroundColor.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
