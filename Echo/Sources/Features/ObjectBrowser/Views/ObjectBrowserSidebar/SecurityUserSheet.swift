import SwiftUI
import SQLServerKit

struct SecurityUserSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let databaseName: String
    /// Non-nil when editing; nil for create mode.
    let existingUserName: String?
    let onComplete: () -> Void

    @State var selectedPage: UserPage = .general

    @State var userName = ""
    @State var loginName = ""
    @State var defaultSchema = "dbo"
    @State var userType: UserTypeChoice = .mappedToLogin

    // Role Membership
    @State var availableRoles: [RoleMemberEntry] = []
    @State var loadingRoles = false

    // Available logins for picker
    @State var availableLogins: [String] = []

    @State var errorMessage: String?
    @State var isSubmitting = false
    @State var isLoading = true

    var isEditing: Bool { existingUserName != nil }

    var isFormValid: Bool {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if userType == .mappedToLogin && loginName.isEmpty { return false }
        return true
    }

    var pages: [UserPage] {
        [.general, .membership]
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
        .frame(minWidth: 640, minHeight: 460)
        .frame(idealWidth: 680, idealHeight: 500)
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
                ProgressView("Loading user properties\u{2026}")
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
        case .membership:
            membershipPage
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack {
            if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                onComplete()
            }
            .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Create User") {
                Task { await submit() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md)
    }

    // MARK: - General Page

    @ViewBuilder
    private var generalPage: some View {
        Section(isEditing ? "User Properties" : "New Database User") {
            if isEditing {
                LabeledContent("User Name", value: userName)
            } else {
                TextField("User Name", text: $userName)
            }

            if !isEditing {
                Picker("User Type", selection: $userType) {
                    Text("Mapped to Login").tag(UserTypeChoice.mappedToLogin)
                    Text("Without Login").tag(UserTypeChoice.withoutLogin)
                }
            }
        }

        if userType == .mappedToLogin {
            Section("Login Mapping") {
                if availableLogins.isEmpty {
                    TextField("Login Name", text: $loginName)
                } else {
                    Picker("Login Name", selection: $loginName) {
                        Text("Select a login\u{2026}").tag("")
                        ForEach(availableLogins, id: \.self) { login in
                            Text(login).tag(login)
                        }
                    }
                }
            }
        }

        Section("Schema") {
            TextField("Default Schema", text: $defaultSchema, prompt: Text("dbo"))
        }

        Section {
            LabeledContent("Database", value: databaseName)
        }
    }

    // MARK: - Membership Page

    @ViewBuilder
    private var membershipPage: some View {
        if loadingRoles {
            Section {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading database roles\u{2026}")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        } else {
            Section("Database Role Membership") {
                ForEach($availableRoles) { $role in
                    Toggle(isOn: $role.isMember) {
                        HStack {
                            Text(role.name)
                            if role.isFixed {
                                Text("(fixed)")
                                    .font(TypographyTokens.label)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        }
                    }
                    .disabled(role.name == "public")
                }
            }
        }
    }
}
