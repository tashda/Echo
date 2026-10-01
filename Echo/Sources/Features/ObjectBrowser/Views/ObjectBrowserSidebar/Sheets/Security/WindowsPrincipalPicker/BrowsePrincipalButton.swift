import SwiftUI
import ActiveDirectory

/// Reusable "Browse" button that opens the AD picker, seeded with the
/// connection's resolved Windows credentials. Used by both the server
/// LoginEditor and the database UserEditor.
///
/// Opens the picker as its own resizable, movable window (not a sheet) — the
/// user can drag it aside while keeping the Login Editor visible underneath.
struct BrowsePrincipalButton: View {

    let connectionSessionID: UUID
    let connection: SavedConnection
    /// Called with the principal's NT-style account name (e.g. `CORP\jdoe`).
    let onSelect: (String) -> Void

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(\.openWindow) private var openWindow
    @State private var credentialError: String?
    @State private var errorPresented: Bool = false

    var body: some View {
        Button("Browse") {
            beginBrowse()
        }
        .controlSize(.small)
        .help("Browse Active Directory for users and groups")
        .alert(
            "Couldn't open Active Directory browser",
            isPresented: $errorPresented,
            actions: {
                Button("OK") { errorPresented = false }
            },
            message: { Text(credentialError ?? "") }
        )
    }

    private func beginBrowse() {
        credentialError = nil

        guard let config = environmentState.identityRepository
            .resolveAuthenticationConfiguration(for: connection, overridePassword: nil)
        else {
            credentialError = "Could not resolve credentials for this connection. Open the connection editor and verify the identity or password are set, then try again."
            errorPresented = true
            return
        }

        guard config.method == .windowsIntegrated else {
            credentialError = "Active Directory browsing requires a Windows Integrated connection. This connection uses \(config.method.displayName)."
            errorPresented = true
            return
        }

        let domain = (config.domain ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let username = config.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = config.password ?? ""

        guard !domain.isEmpty else {
            credentialError = "The connection's identity has no domain. Set the domain on the identity and try again."
            errorPresented = true
            return
        }
        guard !username.isEmpty else {
            credentialError = "The connection's identity has no username."
            errorPresented = true
            return
        }
        guard !password.isEmpty else {
            credentialError = "The connection's password is not available — it may not be saved in Keychain."
            errorPresented = true
            return
        }

        let value = environmentState.prepareWindowsPrincipalPickerWindow(
            connectionSessionID: connectionSessionID,
            domain: domain,
            username: username,
            password: password,
            onResult: { accountName in
                if let accountName, !accountName.isEmpty {
                    onSelect(accountName)
                }
            }
        )
        openWindow(id: WindowsPrincipalPickerWindow.sceneID, value: value)
    }
}
