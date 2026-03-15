import SwiftUI
import SQLServerKit

// MARK: - MSSQL General, Options, Automatic, ANSI Pages

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
}
