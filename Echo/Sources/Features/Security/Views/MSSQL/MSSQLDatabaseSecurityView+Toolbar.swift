import SwiftUI

/// Each page's New as the tab's special button in the window toolbar (round 37.5): users and roles
/// open their editor windows, the others their sheets; Encryption makes either key from a menu.
extension MSSQLDatabaseSecurityView {
    var newItem: TabToolbarItem? {
        switch viewModel.selectedSection {
        case .users:
            TabToolbarItem(id: "newUser", title: "New User", symbol: "person.badge.plus", isDisabled: viewModel.selectedDatabase == nil) {
                openEditor(.user)
            }
        case .roles:
            TabToolbarItem(id: "newRole", title: "New Role", symbol: "person.2", isDisabled: viewModel.selectedDatabase == nil) {
                openEditor(.role)
            }
        case .appRoles:
            TabToolbarItem(id: "newAppRole", title: "New App Role", symbol: "app.badge") { showNewAppRoleSheet = true }
        case .schemas:
            TabToolbarItem(id: "newSchema", title: "New Schema", symbol: "folder.badge.plus") { showNewSchemaSheet = true }
        case .certificates:
            nil
        case .masking:
            TabToolbarItem(id: "newMask", title: "New Mask", symbol: "eye.slash") { showNewMaskSheet = true }
        case .securityPolicies:
            TabToolbarItem(id: "newPolicy", title: "New Policy", symbol: "shield") { showNewRLSPolicySheet = true }
        case .auditSpecifications:
            TabToolbarItem(id: "newAuditSpec", title: "New Audit Specification", symbol: "plus") { showNewAuditSpecSheet = true }
        case .alwaysEncrypted:
            TabToolbarItem(id: "newKey", title: "New Key", symbol: "key.fill", menu: [
                TabToolbarItem(id: "newCMK", title: "New Column Master Key", symbol: "key") { showNewCMKSheet = true },
                TabToolbarItem(id: "newCEK", title: "New Column Encryption Key", symbol: "key.horizontal") { showNewCEKSheet = true },
            ])
        }
    }

    enum EditorKind { case user, role }

    /// Reads the database when pressed.
    private func openEditor(_ kind: EditorKind) {
        guard let database = viewModel.selectedDatabase else { return }
        switch kind {
        case .user:
            let value = environmentState.prepareUserEditorWindow(connectionSessionID: viewModel.connectionID, database: database, existingUser: nil)
            openWindow(id: UserEditorWindow.sceneID, value: value)
        case .role:
            let value = environmentState.prepareRoleEditorWindow(connectionSessionID: viewModel.connectionID, database: database, existingRole: nil)
            openWindow(id: RoleEditorWindow.sceneID, value: value)
        }
    }
}
