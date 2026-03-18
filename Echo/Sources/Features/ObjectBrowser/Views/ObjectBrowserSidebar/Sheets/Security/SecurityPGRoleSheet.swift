import SwiftUI
import PostgresKit

struct SecurityPGRoleSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing; nil for create mode.
    let existingRoleName: String?
    let onComplete: () -> Void

    @State var selectedPage: PGRolePage = .general

    @State var roleName = ""
    @State var password = ""
    @State var confirmPassword = ""
    @State var canLogin = true
    @State var isSuperuser = false
    @State var canCreateDB = false
    @State var canCreateRole = false
    @State var inherit = true
    @State var isReplication = false
    @State var bypassRLS = false
    @State var connectionLimit = -1
    @State var validUntil = ""
    @State var validUntilDate: Date = Date()
    @State var hasExpiry = false

    // Membership
    @State var memberOfEntries: [PGRoleMemberEntry] = []
    @State var memberEntries: [PGRoleMemberEntry] = []
    @State var availableRolesForMemberOf: [String] = []
    @State var availableRolesForMembers: [String] = []
    @State var selectedNewMemberOfRole = ""
    @State var selectedNewMemberRole = ""
    @State var loadingRoles = false

    // Comment
    @State var roleComment = ""

    // Parameters
    @State var roleParameters: [PostgresDatabaseParameter] = []
    @State var newParamName = ""
    @State var newParamValue = ""
    @State var settingDefinitions: [PostgresSettingDefinition] = []

    // Security labels
    @State var securityLabels: [PostgresSecurityLabel] = []
    @State var newLabelProvider = ""
    @State var newLabelValue = ""

    @State var errorMessage: String?
    @State var isSubmitting = false
    @State var isLoading = true

    var isEditing: Bool { existingRoleName != nil }

    var isFormValid: Bool {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && !password.isEmpty && password != confirmPassword { return false }
        return true
    }

    var pages: [PGRolePage] {
        if isEditing {
            return [.general, .privileges, .membership, .parameters, .securityLabels, .sql]
        } else {
            var p: [PGRolePage] = [.general, .privileges, .membership]
            if showParametersInCreateMode { p.append(.parameters) }
            return p
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 170)

                Divider()

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            toolbarView
        }
        .frame(minWidth: 640, minHeight: 480)
        .frame(idealWidth: 680, idealHeight: 520)
        .task { await loadInitialData() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(pages, id: \.self, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.Background.secondary.opacity(0.3))
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading role properties\u{2026}")
                Spacer()
            }
        } else {
            Form {
                pageContent
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            generalPage
        case .privileges:
            privilegesPage
        case .membership:
            membershipPage
        case .parameters:
            parametersPage
        case .securityLabels:
            securityLabelsPage
        case .sql:
            sqlPage
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack {
            if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                Text(error)
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                onComplete()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Create Role") {
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md)
    }
}
