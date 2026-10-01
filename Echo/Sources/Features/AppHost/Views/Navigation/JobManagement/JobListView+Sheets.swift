import SwiftUI
import SQLServerKit

extension JobListView {
    // MARK: - Alert Sheets

    var alertSheets: some View {
        Group {
            EmptyView()
        }
        .sheet(isPresented: $showNewAlertSheet) {
            AgentAlertEditorSheet(
                databaseNames: viewModel.databaseNames
            ) { name, severity, messageId, db, keyword, enabled in
                let error = await viewModel.createAlert(name: name, severity: severity, messageId: messageId, databaseName: db, eventDescriptionKeyword: keyword, enabled: enabled)
                if error == nil { showNewAlertSheet = false }
                return error
            } onCancel: {
                showNewAlertSheet = false
            }
        }
        .sheet(item: $editingAlert) { alert in
            let alertInfo = SQLServerAgentAlertInfo(
                name: alert.name,
                severity: alert.severity,
                messageId: alert.messageId,
                databaseName: alert.databaseName,
                enabled: alert.enabled
            )
            AgentAlertEditorSheet(
                alert: alertInfo,
                databaseNames: viewModel.databaseNames
            ) { name, severity, messageId, db, keyword, enabled in
                let error = await viewModel.updateAlert(originalName: alert.name, name: name, severity: severity, messageId: messageId, databaseName: db, eventDescriptionKeyword: keyword, enabled: enabled)
                if error == nil { editingAlert = nil }
                return error
            } onCancel: {
                editingAlert = nil
            }
        }
        .sheet(isPresented: $showProxySheet) {
            AgentProxyEditorSheet(
                availableLogins: viewModel.logins,
                onSave: { name, credential, enabled in
                    let error = await viewModel.createProxy(name: name, credentialName: credential, description: nil, enabled: enabled)
                    if error == nil { showProxySheet = false }
                    return error
                },
                onCancel: { showProxySheet = false }
            )
        }
        .sheet(item: $editingProxy) { proxy in
            AgentProxyEditorSheet(
                proxyName: proxy.name,
                credentialName: proxy.credentialName ?? "",
                enabled: proxy.enabled,
                isEditing: true,
                availableLogins: viewModel.logins,
                onSave: { _, _, _ in
                    editingProxy = nil
                    return nil
                },
                onGrantLogin: { proxy, login in
                    await viewModel.grantLoginToProxy(proxyName: proxy, loginName: login)
                },
                onRevokeLogin: { proxy, login in
                    await viewModel.revokeLoginFromProxy(proxyName: proxy, loginName: login)
                },
                onGrantSubsystem: { proxy, subsystem in
                    await viewModel.grantProxyToSubsystem(proxyName: proxy, subsystem: subsystem)
                },
                onRevokeSubsystem: { proxy, subsystem in
                    await viewModel.revokeProxyFromSubsystem(proxyName: proxy, subsystem: subsystem)
                },
                loadSubsystems: { proxy in
                    await viewModel.loadProxySubsystems(proxyName: proxy)
                },
                loadLogins: { proxy in
                    await viewModel.loadProxyLogins(proxyName: proxy)
                },
                onCancel: { editingProxy = nil }
            )
        }
        .sheet(isPresented: $showCategorySheet) {
            AgentCategoryManagerSheet(
                categories: viewModel.categories,
                onCreate: { name in await viewModel.createCategory(name: name) },
                onRename: { old, new in await viewModel.renameCategory(name: old, newName: new) },
                onDelete: { name in await viewModel.deleteCategoryAction(name: name) },
                onDismiss: { showCategorySheet = false }
            )
        }
        .alert("Delete Alert?", isPresented: $showDeleteAlertAlert) {
            Button("Cancel", role: .cancel) { pendingDeleteAlertName = nil }
            Button("Delete", role: .destructive) {
                guard let name = pendingDeleteAlertName else { return }
                pendingDeleteAlertName = nil
                Task { await viewModel.deleteAlert(name: name) }
            }
        } message: {
            if let name = pendingDeleteAlertName {
                Text("Are you sure you want to delete alert \"\(name)\"? This action cannot be undone.")
            }
        }
    }
}
