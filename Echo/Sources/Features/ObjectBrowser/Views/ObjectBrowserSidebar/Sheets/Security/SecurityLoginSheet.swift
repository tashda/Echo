import SwiftUI
import SQLServerKit

struct SecurityLoginSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    /// Non-nil when editing an existing login; nil for create mode.
    let existingLoginName: String?
    let onComplete: () -> Void

    @State var selectedPage: LoginPage = .general

    @State var loginName = ""
    @State var authType: AuthType = .sql
    @State var password = ""
    @State var confirmPassword = ""
    @State var defaultDatabase = "master"
    @State var defaultLanguage = ""
    @State var enforcePasswordPolicy = true
    @State var enforcePasswordExpiration = false
    @State var loginEnabled = true

    // Server Roles
    @State var availableServerRoles: [RoleEntry] = []
    @State var loadingRoles = false

    // Database Mapping
    @State var databaseMappings: [LoginDatabaseMapping] = []
    @State var loadingMappings = false
    @State var availableDatabases: [String] = ["master"]
    @State var newMappingDatabase = ""
    @State var newMappingUser = ""

    // Database mapping SSMS-style
    @State var databaseMappingEntries: [DatabaseMappingEntry] = []
    @State var selectedMappingDatabase: String?
    @State var databaseRoleMemberships: [DatabaseRoleMembershipEntry] = []
    @State var loadingDatabaseRoles = false

    @State var errorMessage: String?
    @State var isSubmitting = false
    @State var isLoading = true

    var isEditing: Bool { existingLoginName != nil }

    var isFormValid: Bool {
        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && authType == .sql {
            guard !password.isEmpty, password == confirmPassword else { return false }
        }
        return true
    }

    var pages: [LoginPage] {
        if isEditing {
            return [.general, .serverRoles, .databaseMapping]
        } else {
            return [.general, .serverRoles]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: 170)

                Divider()

                // Detail pane
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

    var sidebar: some View {
        List(pages, id: \.self, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    var detailPane: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading login properties\u{2026}")
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
    var pageContent: some View {
        switch selectedPage {
        case .general:
            generalPage
        case .serverRoles:
            serverRolesPage
        case .databaseMapping:
            databaseMappingPage
        }
    }

    // MARK: - Toolbar

    var toolbarView: some View {
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

            Button(isEditing ? "Save" : "Create Login") {
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md)
    }
}
