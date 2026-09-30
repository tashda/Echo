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

    /// What stops the form from saving, keyed by the field to flag. Save and Connect stay
    /// enabled; pressing them shows these inline and moves focus to the first (CR1).
    internal var validationIssues: [EditorField: String] {
        var issues: [EditorField: String] = [:]
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.isEmpty {
            issues[.host] = selectedDatabaseType == .sqlite ? "Choose a database file." : "Enter the server's host name or address."
        }
        guard selectedDatabaseType != .sqlite else { return issues }

        if !(1...65535).contains(port) {
            issues[.port] = "Enter a port between 1 and 65535."
        }
        switch credentialSource {
        case .manual:
            if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues[.username] = "Enter a user name."
            }
        case .identity:
            if identityID == nil { issues[.username] = "Choose an identity." }
        case .inherit:
            if folderID == nil || inheritedIdentity == nil { issues[.username] = "The folder has no identity to inherit." }
        }
        if authenticationMethod == .windowsIntegrated {
            if domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues[.domain] = "Enter the Windows domain." }
            if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues[.password] = "Enter the Windows password." }
        }
        if authenticationMethod == .accessToken,
           password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !(hasSavedPassword && !passwordDirty) {
            issues[.password] = "Enter an access token."
        }
        return issues
    }

    internal var isFormValid: Bool { validationIssues.isEmpty }

    /// Saves, connects or both, unless something is missing: then the messages appear and the
    /// first field with a problem takes focus.
    internal func submit(_ action: SaveAction) {
        let issues = validationIssues
        guard issues.isEmpty else {
            withAnimation { showsValidation = true }
            let order: [EditorField] = [.host, .port, .username, .domain, .password, .name]
            focusedField = order.first { issues[$0] != nil }
            return
        }
        showsValidation = false
        handleSave(action: action)
    }

    /// A pasted connection URL or string fills the form (CR3).
    internal func applyPastedConnectionString(_ text: String) {
        guard let parsed = ConnectionStringParser.parse(text) else { return }
        if parsed.databaseType != selectedDatabaseType { selectedDatabaseType = parsed.databaseType }
        host = parsed.host
        port = parsed.port ?? parsed.databaseType.defaultPort
        if let value = parsed.database { database = value }
        if let value = parsed.username { username = value; credentialSource = .manual }
        if let value = parsed.password { password = value; passwordDirty = true }
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
