import SwiftUI

/// Account section in Settings — sign in/out, linked accounts, device list placeholder, account deletion.
struct AccountSettingsView: View {
    @Environment(AuthState.self) private var authState

    @State private var showDeleteConfirmation = false

    var body: some View {
        if authState.isSignedIn {
            signedInContent
        } else {
            SignInView(authState: authState)
        }
    }

    // MARK: - Signed In

    private var signedInContent: some View {
        Form {
            profileSection
            linkedAccountsSection
            devicesSection
            dangerZoneSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await authState.deleteAccount()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all synced data. This cannot be undone.")
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section("Profile") {
            PropertyRow(title: "Signed in as") {
                Text(authState.currentUser?.displayName ?? authState.currentUser?.email ?? "User")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            if let email = authState.currentUser?.email {
                PropertyRow(title: "Email") {
                    Text(email)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            PropertyRow(title: "Auth method") {
                if let method = authState.currentUser?.authMethod {
                    Label(method.displayName, systemImage: method.systemImage)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            PropertyRow(title: "Session") {
                Button("Sign Out") {
                    Task { await authState.signOut() }
                }
            }
        }
    }

    // MARK: - Linked Accounts

    private var linkedAccountsSection: some View {
        Section {
            if let linked = authState.currentUser?.linkedMethods, !linked.isEmpty {
                ForEach(linked) { method in
                    PropertyRow(title: method.displayName) {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Status.success)
                            .font(TypographyTokens.formDescription)
                    }
                }
            } else {
                Text("No additional sign-in methods linked.")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        } header: {
            Text("Linked Accounts")
        } footer: {
            Text("Link additional sign-in methods so you can access your account even if one method becomes unavailable.")
        }
    }

    // MARK: - Devices

    private var devicesSection: some View {
        Section {
            Text("Device sync will be available when cloud services are enabled.")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Text.tertiary)
        } header: {
            Text("Devices")
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        Section {
            PropertyRow(
                title: "Delete Account",
                subtitle: "Permanently delete your account and all associated data."
            ) {
                Button("Delete Account...", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
    }
}
