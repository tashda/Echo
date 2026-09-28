import SwiftUI

extension MSSQLDatabaseSecurityView {
    @ViewBuilder
    var sectionContent: some View {
        VStack(spacing: 0) {
            if !(session?.permissions?.canManageRoles ?? true) {
                PermissionBanner(message: "Some operations require the securityadmin or sysadmin role.")
            }

            if isCurrentSectionLoading {
                TabInitializingPlaceholder(
                    icon: "lock.shield",
                    title: "Loading Database Security",
                    subtitle: "Fetching \(viewModel.selectedSection.rawValue.lowercased())…"
                )
            } else if isCurrentSectionEmpty {
                emptyState
            } else {
                populatedSection
            }
        }
        .tabContentFrame()
    }

    @ViewBuilder
    private var populatedSection: some View {
        switch viewModel.selectedSection {
        case .users: MSSQLSecurityUsersSection(viewModel: viewModel)
        case .roles: MSSQLSecurityRolesSection(viewModel: viewModel) { showNewRoleSheet = true }
        case .appRoles: MSSQLSecurityAppRolesSection(viewModel: viewModel) { showNewAppRoleSheet = true }
        case .schemas: MSSQLSecuritySchemasSection(viewModel: viewModel) { showNewSchemaSheet = true }
        case .certificates: MSSQLSecurityCertificatesSection(viewModel: viewModel)
        case .masking: MSSQLSecurityMaskingSection(viewModel: viewModel) { showNewMaskSheet = true }
        case .securityPolicies: MSSQLSecurityPoliciesSection(viewModel: viewModel) { showNewRLSPolicySheet = true }
        case .auditSpecifications: MSSQLSecurityDBAuditSpecSection(viewModel: viewModel) { showNewAuditSpecSheet = true }
        case .alwaysEncrypted:
            MSSQLSecurityAlwaysEncryptedSection(
                viewModel: viewModel,
                onNewCMK: { showNewCMKSheet = true },
                onNewCEK: { showNewCEKSheet = true }
            )
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch viewModel.selectedSection {
        case .users:
            unavailable("No Database Users", image: "person.crop.circle.badge.questionmark", description: "No database users were returned.")
        case .roles:
            unavailable("No Database Roles", image: "person.3", description: "No database roles are configured.") {
                Button("New Role") { showNewRoleSheet = true }.buttonStyle(.bordered)
            }
        case .appRoles:
            unavailable("No Application Roles", image: "app.badge", description: "No application roles are configured.") {
                Button("New Application Role") { showNewAppRoleSheet = true }.buttonStyle(.bordered)
            }
        case .schemas:
            unavailable("No Schemas", image: "rectangle.stack", description: "No database schemas were returned.") {
                Button("New Schema") { showNewSchemaSheet = true }.buttonStyle(.bordered)
            }
        case .certificates:
            unavailable("No Certificates or Keys", image: "key.horizontal", description: "No certificates or asymmetric keys were found.")
        case .masking:
            unavailable("No Masked Columns", image: "theatermasks", description: "Dynamic data masking is not configured.") {
                Button("New Mask") { showNewMaskSheet = true }.buttonStyle(.bordered)
            }
        case .securityPolicies:
            unavailable("No Row-Level Security Policies", image: "checkmark.shield", description: "No row-level security policies are configured.") {
                Button("New Policy") { showNewRLSPolicySheet = true }.buttonStyle(.bordered)
            }
        case .auditSpecifications:
            unavailable("No Audit Specifications", image: "doc.text.magnifyingglass", description: "No database audit specifications are configured.") {
                Button("New Audit Specification") { showNewAuditSpecSheet = true }.buttonStyle(.bordered)
            }
        case .alwaysEncrypted:
            unavailable("No Always Encrypted Keys", image: "lock.shield", description: "No column master or column encryption keys are configured.") {
                Button("New Master Key") { showNewCMKSheet = true }.buttonStyle(.bordered)
                Button("New Encryption Key") { showNewCEKSheet = true }.buttonStyle(.bordered)
            }
        }
    }

    private func unavailable<Actions: View>(
        _ title: LocalizedStringKey,
        image: String,
        description: LocalizedStringKey,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        TabContentUnavailableView(title, systemImage: image) { Text(description) } actions: { actions() }
    }

    private func unavailable(
        _ title: LocalizedStringKey,
        image: String,
        description: LocalizedStringKey
    ) -> some View {
        TabContentUnavailableView(title, systemImage: image) { Text(description) }
    }

    private var isCurrentSectionLoading: Bool {
        switch viewModel.selectedSection {
        case .users: viewModel.isLoadingUsers
        case .roles: viewModel.isLoadingRoles
        case .appRoles: viewModel.isLoadingAppRoles
        case .schemas: viewModel.isLoadingSchemas
        case .certificates: viewModel.isLoadingCertificates
        case .masking: viewModel.isLoadingMaskedColumns
        case .securityPolicies: viewModel.isLoadingSecurityPolicies
        case .auditSpecifications: viewModel.isLoadingDBAuditSpecs
        case .alwaysEncrypted: viewModel.isLoadingAlwaysEncrypted
        }
    }

    private var isCurrentSectionEmpty: Bool {
        switch viewModel.selectedSection {
        case .users: viewModel.users.isEmpty
        case .roles: viewModel.roles.isEmpty
        case .appRoles: viewModel.appRoles.isEmpty
        case .schemas: viewModel.schemas.isEmpty
        case .certificates: viewModel.certificates.isEmpty && viewModel.asymmetricKeys.isEmpty
        case .masking: viewModel.maskedColumns.isEmpty
        case .securityPolicies: viewModel.securityPolicies.isEmpty
        case .auditSpecifications: viewModel.dbAuditSpecs.isEmpty
        case .alwaysEncrypted: viewModel.columnMasterKeys.isEmpty && viewModel.columnEncryptionKeys.isEmpty
        }
    }
}
