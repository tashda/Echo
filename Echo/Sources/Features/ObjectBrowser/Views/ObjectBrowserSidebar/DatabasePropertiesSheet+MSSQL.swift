import SwiftUI
import SQLServerKit

// MARK: - MSSQL Pages

extension DatabasePropertiesSheet {

    @ViewBuilder
    func mssqlGeneralPage(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Information") {
            LabeledContent("Name", value: props.name)
            LabeledContent("Owner", value: props.owner)
            LabeledContent("Status", value: props.stateDescription)
            LabeledContent("Date Created", value: props.createDate)
            LabeledContent("Size", value: String(format: "%.2f MB", props.sizeMB))
            LabeledContent("Active Sessions", value: "\(props.activeSessions)")
            LabeledContent("Collation", value: props.collationName)
        }

        Section("Backup") {
            LabeledContent("Last Database Backup", value: props.lastBackupDate ?? "Never")
            LabeledContent("Last Log Backup", value: props.lastLogBackupDate ?? "Never")
        }

        if let version = session.databaseStructure?.serverVersion {
            Section("Server") {
                LabeledContent("Version", value: version)
            }
        }
    }

    @ViewBuilder
    func mssqlOptionsPage(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Recovery") {
            Picker("Recovery Model", selection: $recoveryModel) {
                ForEach(SQLServerDatabaseOption.RecoveryModel.allCases, id: \.self) { model in
                    Text(model.rawValue).tag(model)
                }
            }
            .onChange(of: recoveryModel) { _, v in applyMSSQLOption(.recoveryModel(v)) }

            Picker("Page Verify", selection: $pageVerify) {
                ForEach(SQLServerDatabaseOption.PageVerifyOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .onChange(of: pageVerify) { _, v in applyMSSQLOption(.pageVerify(v)) }

            LabeledContent("Target Recovery Time") {
                HStack(spacing: SpacingTokens.xs) {
                    TextField("", value: $targetRecoveryTime, format: .number)
                        .frame(width: 60)
                        .onSubmit { applyMSSQLOption(.targetRecoveryTime(targetRecoveryTime)) }
                    Text("seconds")
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }

            Picker("Delayed Durability", selection: $delayedDurability) {
                ForEach(SQLServerDatabaseOption.DelayedDurabilityOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .onChange(of: delayedDurability) { _, v in applyMSSQLOption(.delayedDurability(v)) }
        }

        Section("Compatibility") {
            Picker("Compatibility Level", selection: $compatibilityLevel) {
                ForEach(compatibilityLevels, id: \.value) { level in
                    Text(level.label).tag(level.value)
                }
            }
            .onChange(of: compatibilityLevel) { _, v in applyMSSQLOption(.compatibilityLevel(v)) }
        }

        Section("State") {
            Toggle("Read Only", isOn: $isReadOnly)
                .onChange(of: isReadOnly) { _, v in applyMSSQLOption(.readOnly(v)) }

            Picker("User Access", selection: $userAccess) {
                ForEach(SQLServerDatabaseOption.UserAccessOption.allCases, id: \.self) { opt in
                    Text(opt.displayName).tag(opt)
                }
            }
            .onChange(of: userAccess) { _, v in applyMSSQLOption(.userAccess(v)) }

            Toggle("Encryption", isOn: $isEncrypted)
                .onChange(of: isEncrypted) { _, v in applyMSSQLOption(.encryption(v)) }
        }

        Section("Isolation") {
            Toggle("Allow Snapshot Isolation", isOn: $allowSnapshotIsolation)
                .onChange(of: allowSnapshotIsolation) { _, v in applyMSSQLOption(.allowSnapshotIsolation(v)) }

            Toggle("Read Committed Snapshot", isOn: $readCommittedSnapshot)
                .onChange(of: readCommittedSnapshot) { _, v in applyMSSQLOption(.readCommittedSnapshot(v)) }
        }

        Section("Miscellaneous") {
            Toggle("Broker Enabled", isOn: $isBrokerEnabled)
                .onChange(of: isBrokerEnabled) { _, v in applyMSSQLOption(.brokerEnabled(v)) }

            Toggle("Trustworthy", isOn: $isTrustworthy)
                .onChange(of: isTrustworthy) { _, v in applyMSSQLOption(.trustworthy(v)) }

            Picker("Parameterization", selection: $parameterization) {
                ForEach(SQLServerDatabaseOption.ParameterizationOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .onChange(of: parameterization) { _, v in applyMSSQLOption(.parameterization(v)) }
        }
    }

    @ViewBuilder
    func mssqlAutomaticPage() -> some View {
        Section("Statistics") {
            Toggle("Auto Create Statistics", isOn: $autoCreateStats)
                .onChange(of: autoCreateStats) { _, v in applyMSSQLOption(.autoCreateStatistics(v)) }

            Toggle("Auto Update Statistics", isOn: $autoUpdateStats)
                .onChange(of: autoUpdateStats) { _, v in applyMSSQLOption(.autoUpdateStatistics(v)) }

            Toggle("Auto Update Statistics Asynchronously", isOn: $autoUpdateStatsAsync)
                .onChange(of: autoUpdateStatsAsync) { _, v in applyMSSQLOption(.autoUpdateStatisticsAsync(v)) }
        }

        Section("Storage") {
            Toggle("Auto Close", isOn: $autoClose)
                .onChange(of: autoClose) { _, v in applyMSSQLOption(.autoClose(v)) }

            Toggle("Auto Shrink", isOn: $autoShrink)
                .onChange(of: autoShrink) { _, v in applyMSSQLOption(.autoShrink(v)) }
        }
    }

    @ViewBuilder
    func mssqlAnsiPage() -> some View {
        Section("ANSI Defaults") {
            Toggle("ANSI NULL Default", isOn: $ansiNullDefault)
                .onChange(of: ansiNullDefault) { _, v in applyMSSQLOption(.ansiNullDefault(v)) }

            Toggle("ANSI NULLS Enabled", isOn: $ansiNulls)
                .onChange(of: ansiNulls) { _, v in applyMSSQLOption(.ansiNulls(v)) }

            Toggle("ANSI Padding Enabled", isOn: $ansiPadding)
                .onChange(of: ansiPadding) { _, v in applyMSSQLOption(.ansiPadding(v)) }

            Toggle("ANSI Warnings Enabled", isOn: $ansiWarnings)
                .onChange(of: ansiWarnings) { _, v in applyMSSQLOption(.ansiWarnings(v)) }
        }

        Section("Arithmetic") {
            Toggle("Arithmetic Abort Enabled", isOn: $arithAbort)
                .onChange(of: arithAbort) { _, v in applyMSSQLOption(.arithAbort(v)) }

            Toggle("Numeric Round-Abort", isOn: $numericRoundAbort)
                .onChange(of: numericRoundAbort) { _, v in applyMSSQLOption(.numericRoundAbort(v)) }

            Toggle("Concatenate Null Yields Null", isOn: $concatNullYieldsNull)
                .onChange(of: concatNullYieldsNull) { _, v in applyMSSQLOption(.concatNullYieldsNull(v)) }
        }

        Section("Identifiers & Triggers") {
            Toggle("Quoted Identifiers Enabled", isOn: $quotedIdentifier)
                .onChange(of: quotedIdentifier) { _, v in applyMSSQLOption(.quotedIdentifier(v)) }

            Toggle("Recursive Triggers Enabled", isOn: $recursiveTriggers)
                .onChange(of: recursiveTriggers) { _, v in applyMSSQLOption(.recursiveTriggers(v)) }

            Toggle("Date Correlation Optimization", isOn: $dateCorrelation)
                .onChange(of: dateCorrelation) { _, v in applyMSSQLOption(.dateCorrelationOptimization(v)) }
        }
    }

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

    // MARK: - File Editing State Types

    enum FileMaxSizeType: Hashable {
        case unlimited
        case mb
    }

    enum FileGrowthType: Hashable {
        case mb
        case percent
        case none
    }

    // MARK: - File Editing Helpers

    func currentFileMaxSizeType(index: Int, file: SQLServerDatabaseFile) -> FileMaxSizeType {
        fileMaxSizeTypes[index] ?? (file.isMaxSizeUnlimited ? .unlimited : .mb)
    }

    func currentFileGrowthType(index: Int, file: SQLServerDatabaseFile) -> FileGrowthType {
        if let stored = fileGrowthTypes[index] { return stored }
        if file.growthRaw == 0 { return .none }
        return file.isPercentGrowth ? .percent : .mb
    }

    // MARK: - File Editing Bindings

    func fileSizeMBBinding(index: Int) -> Binding<Int> {
        Binding(
            get: { fileSizeMBValues[index] ?? Int(mssqlFiles[index].sizeMB) },
            set: { fileSizeMBValues[index] = $0 }
        )
    }

    func fileMaxSizeTypeBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<FileMaxSizeType> {
        Binding(
            get: { fileMaxSizeTypes[index] ?? (file.isMaxSizeUnlimited ? .unlimited : .mb) },
            set: { newType in
                fileMaxSizeTypes[index] = newType
                switch newType {
                case .unlimited:
                    applyMSSQLFileOption(file: file, option: .maxSizeUnlimited)
                case .mb:
                    let currentMB = fileMaxSizeMBValues[index] ?? file.maxSizeMB ?? 256
                    fileMaxSizeMBValues[index] = currentMB
                    applyMSSQLFileOption(file: file, option: .maxSizeMB(currentMB))
                }
            }
        )
    }

    func fileMaxSizeMBBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<Int> {
        Binding(
            get: { fileMaxSizeMBValues[index] ?? file.maxSizeMB ?? 256 },
            set: { fileMaxSizeMBValues[index] = $0 }
        )
    }

    func fileGrowthTypeBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<FileGrowthType> {
        Binding(
            get: {
                if let stored = fileGrowthTypes[index] { return stored }
                if file.growthRaw == 0 { return .none }
                return file.isPercentGrowth ? .percent : .mb
            },
            set: { newType in
                fileGrowthTypes[index] = newType
                switch newType {
                case .none:
                    applyMSSQLFileOption(file: file, option: .filegrowthNone)
                case .mb:
                    let currentMB = fileGrowthValues[index] ?? file.growthMB ?? 64
                    fileGrowthValues[index] = currentMB
                    applyMSSQLFileOption(file: file, option: .filegrowthMB(currentMB))
                case .percent:
                    let currentPct = fileGrowthValues[index] ?? file.growthPercent ?? 10
                    fileGrowthValues[index] = currentPct
                    applyMSSQLFileOption(file: file, option: .filegrowthPercent(currentPct))
                }
            }
        )
    }

    func fileGrowthValueBinding(index: Int, file: SQLServerDatabaseFile) -> Binding<Int> {
        Binding(
            get: {
                if let stored = fileGrowthValues[index] { return stored }
                if file.isPercentGrowth { return file.growthPercent ?? 10 }
                return file.growthMB ?? 64
            },
            set: { fileGrowthValues[index] = $0 }
        )
    }

    func applyFileGrowthChange(index: Int, file: SQLServerDatabaseFile) {
        let growthType = fileGrowthTypes[index] ?? (file.isPercentGrowth ? .percent : .mb)
        let value = fileGrowthValues[index] ?? (file.isPercentGrowth ? file.growthPercent ?? 10 : file.growthMB ?? 64)
        switch growthType {
        case .mb:
            applyMSSQLFileOption(file: file, option: .filegrowthMB(value))
        case .percent:
            applyMSSQLFileOption(file: file, option: .filegrowthPercent(value))
        case .none:
            applyMSSQLFileOption(file: file, option: .filegrowthNone)
        }
    }
}
