import SwiftUI
#if os(macOS)
import AppKit
#endif

extension ConnectionEditorView {
    func startConnectionTest() {
        cancelActiveTest()
        isTestingConnection = true
        testResult = nil
        testLogEntries = []

        appendLog("Resolving credentials...", kind: .info)

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedAuthenticationMethod: DatabaseAuthenticationMethod = {
            if selectedDatabaseType == .sqlite {
                return .sqlPassword
            }
            let supported = selectedDatabaseType.supportedAuthenticationMethods
            return supported.contains(authenticationMethod) ? authenticationMethod : selectedDatabaseType.defaultAuthenticationMethod
        }()

        var sanitizedCredentialSource = selectedDatabaseType == .sqlite ? .manual : credentialSource
        if !sanitizedAuthenticationMethod.supportsExternalCredentials {
            sanitizedCredentialSource = .manual
        }

        let connection = SavedConnection(
            id: originalConnection?.id ?? UUID(),
            projectID: originalConnection?.projectID ?? projectStore.selectedProject?.id,
            connectionName: connectionName,
            host: host,
            port: selectedDatabaseType == .sqlite ? 0 : port,
            database: selectedDatabaseType == .sqlite ? "" : database,
            username: selectedDatabaseType == .sqlite ? "" : trimmedUsername,
            authenticationMethod: sanitizedAuthenticationMethod,
            domain: selectedDatabaseType == .sqlite ? "" : trimmedDomain,
            credentialSource: sanitizedCredentialSource,
            identityID: selectedDatabaseType == .sqlite ? nil : identityID,
            keychainIdentifier: originalConnection?.keychainIdentifier,
            folderID: folderID,
            useTLS: selectedDatabaseType == .sqlite ? false : useTLS,
            trustServerCertificate: selectedDatabaseType == .microsoftSQL ? trustServerCertificate : false,
            tlsMode: selectedDatabaseType == .postgresql ? tlsMode : .prefer,
            sslRootCertPath: sslRootCertPath,
            sslCertPath: selectedDatabaseType == .postgresql ? sslCertPath : nil,
            sslKeyPath: selectedDatabaseType == .postgresql ? sslKeyPath : nil,
            mssqlEncryptionMode: selectedDatabaseType == .microsoftSQL ? mssqlEncryptionMode : .optional,
            databaseType: selectedDatabaseType,
            serverVersion: nil,
            colorHex: colorHex,
            cachedStructure: nil,
            cachedStructureUpdatedAt: nil
        )

        let overridePassword: String?
        if selectedDatabaseType == .sqlite {
            overridePassword = nil
        } else if sanitizedCredentialSource == .manual && !password.isEmpty {
            overridePassword = password
        } else {
            overridePassword = nil
        }

        if selectedDatabaseType == .sqlite {
            appendLog("Opening database at \(host)...", kind: .info)
        } else {
            appendLog("Connecting to \(host):\(port)...", kind: .info)
            if sanitizedCredentialSource == .manual && !trimmedUsername.isEmpty {
                appendLog("Authenticating as \(trimmedUsername)...", kind: .info)
            } else if sanitizedCredentialSource == .identity {
                appendLog("Using identity credentials...", kind: .info)
            } else if sanitizedCredentialSource == .inherit {
                appendLog("Using inherited credentials...", kind: .info)
            }
        }

        testTask = Task {
            await runConnectionTest(connection: connection, passwordOverride: overridePassword)
        }
    }

    func cancelActiveTest() {
        testTask?.cancel()
        testTask = nil
        if isTestingConnection {
            appendLog("Test cancelled.", kind: .error)
        }
        isTestingConnection = false
    }

    /// Driver timeout in seconds — the packages use this for their TCP connect timeout.
    /// Echo's own fallback fires 1 second later so the driver's real error always wins.
    static let driverTimeoutSeconds = 10

    func runConnectionTest(connection: SavedConnection, passwordOverride: String?) async {
        let driverTimeout = Self.driverTimeoutSeconds
        let fallbackNanos = UInt64(driverTimeout + 1) * 1_000_000_000

        // Start a concurrent timeout task and the actual test in parallel
        let timeoutTask = Task<ConnectionTestResult, Error> {
            try await Task.sleep(nanoseconds: fallbackNanos)
            return ConnectionTestResult(
                isSuccessful: false,
                message: "Connection timed out. The server may be unreachable.",
                responseTime: Double(driverTimeout + 1),
                serverVersion: nil
            )
        }

        let testTask = Task<ConnectionTestResult, Never> {
            await environmentState.testConnection(
                connection,
                passwordOverride: passwordOverride,
                connectTimeoutSeconds: driverTimeout
            )
        }

        // Wait for whichever finishes first
        let result: ConnectionTestResult
        do {
            result = try await withThrowingTaskGroup(of: ConnectionTestResult.self) { group in
                group.addTask { await testTask.value }
                group.addTask { try await timeoutTask.value }
                guard let first = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return first
            }
        } catch {
            testResult = ConnectionTestResult(
                isSuccessful: false,
                message: "Connection test cancelled",
                responseTime: nil,
                serverVersion: nil
            )
            isTestingConnection = false
            self.testTask = nil
            appendLog("Test cancelled.", kind: .error)
            return
        }

        // Clean up
        timeoutTask.cancel()

        guard !Task.isCancelled else {
            testResult = ConnectionTestResult(
                isSuccessful: false,
                message: "Connection test cancelled",
                responseTime: nil,
                serverVersion: nil
            )
            isTestingConnection = false
            self.testTask = nil
            return
        }

        testResult = result
        isTestingConnection = false
        self.testTask = nil

        if result.success {
            var successMsg = "Connected successfully"
            if let time = result.responseTime {
                successMsg += String(format: " (%.0fms)", time * 1000)
            }
            if let version = result.serverVersion, !version.isEmpty {
                successMsg += " — \(version)"
            }
            appendLog(successMsg, kind: .success)
        } else {
            appendLog("Failed: \(result.message)", kind: .error)
        }
    }

    func appendLog(_ message: String, kind: TestLogEntry.Kind) {
        testLogEntries.append(TestLogEntry(timestamp: Date(), message: message, kind: kind))
    }
}
