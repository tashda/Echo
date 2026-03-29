import SwiftUI
import PostgresKit
import SQLServerKit

// MARK: - Security Context Menu & UI Helpers

extension ObjectBrowserSidebarView {
    enum SecuritySidebarDepth {
        static let serverSection = 1
        static let serverNestedSection = 2
        static let serverLeaf = 2

        static let databaseSection = 3
        static let databaseLeaf = 4
    }

    // MARK: - Security Folder Context Menu

    @ViewBuilder
    func securityFolderContextMenu(session: ConnectionSession) -> some View {
        let connID = session.connection.id

        // Group 1: Refresh
        Button {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing security", connectionSessionID: session.id)
                await loadServerSecurityAsync(session: session)
                handle.succeed()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        switch session.connection.databaseType {
        case .microsoftSQL:
            Button {
                let value = environmentState.prepareLoginEditorWindow(
                    connectionSessionID: connID,
                    existingLogin: nil
                )
                openWindow(id: LoginEditorWindow.sceneID, value: value)
            } label: {
                Label("New Login", systemImage: "person.badge.plus")
            }
        case .postgresql:
            Button {
                sheetState.securityPGRoleSheetSessionID = connID
                sheetState.securityPGRoleSheetEditName = nil
                sheetState.showSecurityPGRoleSheet = true
            } label: {
                Label("New Login Role", systemImage: "person.badge.plus")
            }
            Button {
                sheetState.securityPGRoleSheetSessionID = connID
                sheetState.securityPGRoleSheetEditName = nil
                sheetState.showSecurityPGRoleSheet = true
            } label: {
                Label("New Group Role", systemImage: "person.2.badge.plus")
            }
        default:
            EmptyView()
        }

        Divider()

        // Group 3: Open Security Management Tab
        if session.connection.databaseType == .microsoftSQL {
            Button {
                environmentState.openServerSecurityTab(connectionID: session.connection.id)
            } label: {
                Label("Open Security Management", systemImage: "lock.shield")
            }
        }
    }

    // MARK: - Shared UI Helpers

    func securitySectionHeader(depth: Int, title: String, icon: String, count: Int?, isExpanded: Binding<Bool>, isLoading: Bool = false) -> some View {
        let colored = projectStore.globalSettings.sidebarIconColorMode == .colorful
        let iconColor = ExplorerSidebarPalette.folderIconColor(title: title, colored: colored)
        let animatedBinding = Binding<Bool>(
            get: { isExpanded.wrappedValue },
            set: { newValue in
                withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
                    isExpanded.wrappedValue = newValue
                }
            }
        )

        return Button {
            animatedBinding.wrappedValue.toggle()
        } label: {
            SidebarRow(
                depth: depth,
                icon: .system(icon),
                label: title,
                isExpanded: animatedBinding,
                iconColor: iconColor
            ) {
                if let count {
                    Text("\(count)")
                        .font(SidebarRowConstants.trailingFont)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
