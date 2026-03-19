import SwiftUI

struct TestLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let kind: Kind

    enum Kind {
        case info
        case success
        case error
    }
}

extension ConnectionEditorView {

    internal var isFormValid: Bool {
        let trimmedName = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedDatabaseType == .sqlite {
            return !trimmedName.isEmpty && !trimmedHost.isEmpty
        }

        let hasValidPort = (1...65535).contains(port)

        let credentialsValid: Bool
        switch credentialSource {
        case .manual:
            credentialsValid = !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .identity:
            credentialsValid = identityID != nil
        case .inherit:
            credentialsValid = folderID != nil && inheritedIdentity != nil
        }

        if trimmedName.isEmpty || trimmedHost.isEmpty || !hasValidPort {
            return false
        }

        if authenticationMethod == .windowsIntegrated {
            guard credentialSource == .manual else { return false }
            let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedDomain.isEmpty, !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else { return false }
        }

        if authenticationMethod == .accessToken {
            let trimmedToken = password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedToken.isEmpty || (hasSavedPassword && !passwordDirty) else { return false }
        }

        return credentialsValid
    }

    internal func handleDatabaseTypeChange(from oldType: DatabaseType, to newType: DatabaseType) {
        if newType == .sqlite {
            port = 0
            useTLS = false
            credentialSource = .manual
            identityID = nil
            username = ""
            password = ""
            database = ""
            authenticationMethod = .sqlPassword
            domain = ""
        } else {
            if oldType == .sqlite || port == 0 || port == oldType.defaultPort {
                port = newType.defaultPort
            }
            let supportedMethods = newType.supportedAuthenticationMethods
            if !supportedMethods.contains(authenticationMethod) {
                authenticationMethod = newType.defaultAuthenticationMethod
            }
            if authenticationMethod == .windowsIntegrated {
                credentialSource = .manual
            }
        }
    }
}
