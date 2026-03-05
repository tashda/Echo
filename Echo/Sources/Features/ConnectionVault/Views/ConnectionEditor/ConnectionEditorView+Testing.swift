import SwiftUI
#if os(macOS)
import AppKit
#endif

extension ConnectionEditorView {
    func startConnectionTest() {
        cancelActiveTest()
        isTestingConnection = true
        testResult = nil

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
            databaseType: selectedDatabaseType,
            serverVersion: nil,
            colorHex: colorHex,
            cachedStructure: nil,
            cachedStructureUpdatedAt: nil
        )

        let overridePassword: String?
        if selectedDatabaseType == .sqlite {
            overridePassword = nil
        } else {
            overridePassword = sanitizedCredentialSource == .manual ? password : nil
        }
        testTask = Task {
            await runConnectionTest(connection: connection, passwordOverride: overridePassword)
        }
    }

    func cancelActiveTest() {
        testTask?.cancel()
        testTask = nil
        isTestingConnection = false
    }

    func runConnectionTest(connection: SavedConnection, passwordOverride: String?) async {
        do {
            let result = try await withThrowingTaskGroup(of: ConnectionTestResult.self) { group in
                group.addTask {
                    await environmentState.testConnection(connection, passwordOverride: passwordOverride)
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    return ConnectionTestResult(
                        isSuccessful: false,
                        message: "Connection timed out",
                        responseTime: 10.0,
                        serverVersion: nil
                    )
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            guard !Task.isCancelled else {
                await MainActor.run {
                    testResult = ConnectionTestResult(
                        isSuccessful: false,
                        message: "Connection test cancelled",
                        responseTime: nil,
                        serverVersion: nil
                    )
                    isTestingConnection = false
                    self.testTask = nil
                    showingTestAlert = true
                }
                return
            }

            await MainActor.run {
                testResult = result
                isTestingConnection = false
                self.testTask = nil
                showingTestAlert = true
            }
        } catch {
            await MainActor.run {
                testResult = ConnectionTestResult(
                    isSuccessful: false,
                    message: "Connection test cancelled",
                    responseTime: nil,
                    serverVersion: nil
                )
                isTestingConnection = false
                self.testTask = nil
                showingTestAlert = true
            }
        }
    }
}
