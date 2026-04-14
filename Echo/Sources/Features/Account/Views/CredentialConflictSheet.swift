import SwiftUI

/// Presented when pulling credentials from the cloud detects that the local Keychain
/// has different passwords for the same connections/identities.
struct CredentialConflictSheet: View {
    let conflicts: [CredentialConflict]
    let onResolve: (Bool) -> Void // true = use cloud, false = keep local

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                        Label("Credential Conflict", systemImage: "exclamationmark.lock")
                            .font(TypographyTokens.headline)

                        Text("\(conflicts.count) credential\(conflicts.count == 1 ? "" : "s") differ between this device and the cloud. Which version would you like to keep?")
                            .font(TypographyTokens.formDescription)
                            .foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .padding(.bottom, SpacingTokens.xs)

                    // List affected items
                    ForEach(conflicts) { conflict in
                        Label {
                            Text(conflict.displayName)
                        } icon: {
                            Image(systemName: conflict.collection == .connections ? "externaldrive" : "person.crop.circle")
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        onResolve(true)
                        dismiss()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Cloud Passwords")
                                Text("Replace local passwords with the cloud versions. Use this if your cloud data is more up to date.")
                                    .font(TypographyTokens.detail)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        } icon: {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .frame(width: 20)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onResolve(false)
                        dismiss()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Keep Local Passwords")
                                Text("Keep the passwords already on this device. They will be uploaded to the cloud on the next sync.")
                                    .font(TypographyTokens.detail)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                        } icon: {
                            Image(systemName: "laptopcomputer")
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .frame(width: 20)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 420, height: min(CGFloat(300 + conflicts.count * 30), 500))
    }
}
