import SwiftUI
import SQLServerKit

// MARK: - MSSQL Files Page, Apply Options, and Data Loading

extension DatabasePropertiesSheet {

    @ViewBuilder
    func mssqlFilesPage() -> some View {
        if mssqlFiles.isEmpty {
            Section {
                Text("No file information available.")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } else {
            ForEach(Array(mssqlFiles.enumerated()), id: \.offset) { index, file in
                Section(file.name) {
                    LabeledContent("Type", value: file.typeDescription)
                    if let fg = file.fileGroupName {
                        LabeledContent("Filegroup", value: fg)
                    }

                    LabeledContent("Size") {
                        HStack(spacing: SpacingTokens.xs) {
                            TextField("", value: fileSizeMBBinding(index: index), format: .number)
                                .frame(width: 80)
                                .onSubmit {
                                    let newSize = fileSizeMBValues[index] ?? Int(file.sizeMB)
                                    applyMSSQLFileOption(file: file, option: .sizeMB(newSize))
                                }
                            Text("MB")
                                .foregroundStyle(ColorTokens.Text.secondary)
                        }
                    }

                    LabeledContent("Max Size") {
                        HStack(spacing: SpacingTokens.xs) {
                            Picker("", selection: fileMaxSizeTypeBinding(index: index, file: file)) {
                                Text("Unlimited").tag(FileMaxSizeType.unlimited)
                                Text("MB").tag(FileMaxSizeType.mb)
                            }
                            .frame(width: 110)

                            if currentFileMaxSizeType(index: index, file: file) == .mb {
                                TextField("", value: fileMaxSizeMBBinding(index: index, file: file), format: .number)
                                    .frame(width: 80)
                                    .onSubmit {
                                        let newMax = fileMaxSizeMBValues[index] ?? (file.maxSizeMB ?? 256)
                                        applyMSSQLFileOption(file: file, option: .maxSizeMB(newMax))
                                    }
                                Text("MB")
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                    }

                    LabeledContent("Growth") {
                        HStack(spacing: SpacingTokens.xs) {
                            Picker("", selection: fileGrowthTypeBinding(index: index, file: file)) {
                                Text("MB").tag(FileGrowthType.mb)
                                Text("Percent").tag(FileGrowthType.percent)
                                Text("None").tag(FileGrowthType.none)
                            }
                            .frame(width: 110)

                            if currentFileGrowthType(index: index, file: file) != .none {
                                TextField("", value: fileGrowthValueBinding(index: index, file: file), format: .number)
                                    .frame(width: 80)
                                    .onSubmit {
                                        applyFileGrowthChange(index: index, file: file)
                                    }
                                Text(currentFileGrowthType(index: index, file: file) == .percent ? "%" : "MB")
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                    }

                    LabeledContent("Path", value: file.physicalName)
                }
            }
        }
    }

    // MARK: - MSSQL Apply Option

    func applyMSSQLOption(_ option: SQLServerDatabaseOption) {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin
        isSaving = true
        statusMessage = nil

        Task {
            do {
                let messages = try await admin.alterDatabaseOption(name: databaseName, option: option)
                let info = messages.filter { $0.kind == .info }.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                isSaving = false
                if !info.isEmpty { statusMessage = info }
                Task { await environmentState.refreshDatabaseStructure(for: session.id) }
            } catch {
                isSaving = false
                statusMessage = error.localizedDescription
                environmentState.notificationEngine?.post(category: .databasePropertiesError, message: error.localizedDescription)
            }
        }
    }

    // MARK: - MSSQL Apply File Option

    func applyMSSQLFileOption(file: SQLServerDatabaseFile, option: SQLServerDatabaseFileOption) {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin
        isSaving = true
        statusMessage = nil

        Task {
            do {
                let messages = try await admin.modifyDatabaseFile(
                    databaseName: databaseName,
                    logicalFileName: file.name,
                    option: option
                )
                let info = messages.filter { $0.kind == .info }.map(\.message).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                isSaving = false
                if !info.isEmpty { statusMessage = info }
                // Reload files to reflect the change
                if let updatedAdmin = session.session as? MSSQLSession {
                    let freshAdmin = updatedAdmin.admin
                    mssqlFiles = (try? await freshAdmin.fetchDatabaseFiles(name: databaseName)) ?? mssqlFiles
                }
            } catch {
                isSaving = false
                statusMessage = error.localizedDescription
                environmentState.notificationEngine?.post(category: .databasePropertiesError, message: error.localizedDescription)
            }
        }
    }

    // MARK: - MSSQL Data Loading

    func loadMSSQLProperties() async throws {
        guard let mssqlSession = session.session as? MSSQLSession else { return }
        let admin = mssqlSession.admin
        let props = try await admin.fetchDatabaseProperties(name: databaseName)
        mssqlProps = props

        recoveryModel = SQLServerDatabaseOption.RecoveryModel(rawValue: props.recoveryModel) ?? .full
        compatibilityLevel = props.compatibilityLevel
        isReadOnly = props.isReadOnly
        userAccess = SQLServerDatabaseOption.UserAccessOption.fromDescription(props.userAccessDescription)
        pageVerify = SQLServerDatabaseOption.PageVerifyOption(rawValue: props.pageVerifyOption) ?? .checksum
        targetRecoveryTime = props.targetRecoveryTimeSeconds
        delayedDurability = SQLServerDatabaseOption.DelayedDurabilityOption(rawValue: props.delayedDurability) ?? .disabled
        allowSnapshotIsolation = props.snapshotIsolationState.uppercased().contains("ON")
        readCommittedSnapshot = props.isReadCommittedSnapshotOn
        isEncrypted = props.isEncrypted
        isBrokerEnabled = props.isBrokerEnabled
        isTrustworthy = props.isTrustworthy
        parameterization = props.isParameterizationForced ? .forced : .simple
        autoClose = props.isAutoCloseOn
        autoShrink = props.isAutoShrinkOn
        autoCreateStats = props.isAutoCreateStatsOn
        autoUpdateStats = props.isAutoUpdateStatsOn
        autoUpdateStatsAsync = props.isAutoUpdateStatsAsyncOn
        ansiNullDefault = props.isAnsiNullDefaultOn
        ansiNulls = props.isAnsiNullsOn
        ansiPadding = props.isAnsiPaddingOn
        ansiWarnings = props.isAnsiWarningsOn
        arithAbort = props.isArithAbortOn
        concatNullYieldsNull = props.isConcatNullYieldsNullOn
        quotedIdentifier = props.isQuotedIdentifierOn
        recursiveTriggers = props.isRecursiveTriggersOn
        numericRoundAbort = props.isNumericRoundAbortOn
        dateCorrelation = props.isDateCorrelationOn

        mssqlFiles = (try? await admin.fetchDatabaseFiles(name: databaseName)) ?? []
    }
}
