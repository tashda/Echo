import SwiftUI

/// Compact account card shown at the top of General settings when signed in.
/// Shows profile photo (from Google/Apple), name, email, and sign-out.
struct SignedInAccountCard: View {
    @Bindable var authState: AuthState

    @State private var showDeleteConfirmation = false

    var body: some View {
        Section {
            profileRow
            signOutRow
        } header: {
            Text("Echo Account")
        }
    }

    // MARK: - Profile

    private var profileRow: some View {
        HStack(spacing: SpacingTokens.md) {
            accountAvatar

            VStack(alignment: .leading, spacing: 2) {
                Text(authState.currentUser?.displayName ?? "Echo User")
                    .font(TypographyTokens.prominent)

                if let email = authState.currentUser?.email {
                    Text(email)
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                if let method = authState.currentUser?.authMethod {
                    HStack(spacing: 4) {
                        Image(systemName: method.systemImage)
                            .font(.system(size: 10))
                        Text("Signed in with \(method.displayName)")
                            .font(TypographyTokens.detail)
                    }
                    .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, SpacingTokens.xs)
    }

    @ViewBuilder
    private var accountAvatar: some View {
        if let avatarURL = authState.currentUser?.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                default:
                    initialsAvatar
                }
            }
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        ZStack {
            Circle()
                .fill(.quaternary)
                .frame(width: 48, height: 48)

            Text(avatarInitials)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var avatarInitials: String {
        let name = authState.currentUser?.displayName
            ?? authState.currentUser?.email
            ?? "U"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Sign Out

    private var signOutRow: some View {
        HStack {
            Button("Sign Out") {
                Task { await authState.signOut() }
            }

            Spacer()

            Button("Delete Account...", role: .destructive) {
                showDeleteConfirmation = true
            }
            .font(TypographyTokens.formDescription)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { try? await authState.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all synced data. This cannot be undone.")
        }
    }
}
