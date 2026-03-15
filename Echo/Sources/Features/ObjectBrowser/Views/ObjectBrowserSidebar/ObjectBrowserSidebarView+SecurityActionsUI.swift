import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Security Context Menu & UI Helpers

extension ObjectBrowserSidebarView {
    // MARK: - Security Folder Context Menu

    @ViewBuilder
    func securityFolderContextMenu(session: ConnectionSession) -> some View {
        let connID = session.connection.id
        switch session.connection.databaseType {
        case .microsoftSQL:
            Button {
                viewModel.securityLoginSheetSessionID = connID
                viewModel.securityLoginSheetEditName = nil
                viewModel.showSecurityLoginSheet = true
            } label: {
                Label("New Login\u{2026}", systemImage: "plus")
            }
        case .postgresql:
            Button {
                viewModel.securityPGRoleSheetSessionID = connID
                viewModel.securityPGRoleSheetEditName = nil
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("New Login Role\u{2026}", systemImage: "plus")
            }
            Button {
                viewModel.securityPGRoleSheetSessionID = connID
                viewModel.securityPGRoleSheetEditName = nil
                viewModel.showSecurityPGRoleSheet = true
            } label: {
                Label("New Group Role\u{2026}", systemImage: "plus")
            }
        default:
            EmptyView()
        }

        Divider()

        Button {
            loadServerSecurity(session: session)
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }

    // MARK: - Shared UI Helpers

    func securitySectionHeader(title: String, icon: String, count: Int?, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        folderHeaderRow(title: title, icon: icon, count: count, isExpanded: isExpanded, action: action)
    }

    func securityLoadingRow(_ text: String) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Spacer().frame(width: SidebarRowConstants.chevronWidth)
            ProgressView()
                .controlSize(.mini)
            Text(text)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
    }

    // MARK: - New Item Button

    func newItemButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.xs) {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)

                Image(systemName: "plus.circle")
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(width: SidebarRowConstants.iconFrame)

                Text(title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .lineLimit(1)

                Spacer(minLength: SpacingTokens.xxxs)
            }
            .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
                .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Key Helpers

    /// Extracts the database name from a composite key like "UUID#dbName"
    func databaseNameFromKey(_ key: String) -> String {
        if let hashIndex = key.firstIndex(of: "#") {
            return String(key[key.index(after: hashIndex)...])
        }
        return key
    }

    // MARK: - Script Helper

    func openScriptTab(sql: String, session: ConnectionSession) {
        environmentState.openQueryTab(for: session, presetQuery: sql)
    }

    // MARK: - Error Formatting

    func readableErrorMessage(_ error: Error) -> String {
        // PostgresKit's PostgresError already provides good messages via LocalizedError.
        if let pgError = error as? PostgresKit.PostgresError {
            return pgError.message
        }
        // PSQLError now conforms to @retroactive LocalizedError in postgres-wire,
        // so localizedDescription returns the actual server message.
        return error.localizedDescription
    }

    // MARK: - Login Type Display

    func loginTypeDisplayName(_ type: ServerLoginType) -> String {
        switch type {
        case .sql: return "SQL"
        case .windowsUser: return "Windows"
        case .windowsGroup: return "Windows Group"
        case .certificate: return "Certificate"
        case .asymmetricKey: return "Asymmetric Key"
        case .external: return "External"
        }
    }
}
