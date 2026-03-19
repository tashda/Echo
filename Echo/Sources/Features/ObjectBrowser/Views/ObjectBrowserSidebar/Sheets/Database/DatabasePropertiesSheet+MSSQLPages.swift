import SwiftUI
import SQLServerKit

// MARK: - MSSQL General, Options, Automatic, ANSI Pages

extension DatabasePropertiesSheet {

    @ViewBuilder
    func mssqlGeneralPage(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Information") {
            PropertyRow(title: "Name") {
                Text(props.name)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Owner") {
                Text(props.owner)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Status") {
                Text(props.stateDescription)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Date Created") {
                Text(props.createDate)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Size") {
                Text(String(format: "%.2f MB", props.sizeMB))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Active Sessions") {
                Text("\(props.activeSessions)")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Collation") {
                Text(props.collationName)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        Section("Backup") {
            PropertyRow(title: "Last Database Backup") {
                Text(props.lastBackupDate ?? "Never")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            PropertyRow(title: "Last Log Backup") {
                Text(props.lastLogBackupDate ?? "Never")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }

        if let version = session.databaseStructure?.serverVersion {
            Section("Server") {
                PropertyRow(title: "Version") {
                    Text(version)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
        }
    }

    @ViewBuilder
    func mssqlOptionsPage(_ props: SQLServerDatabaseProperties) -> some View {
        Section("Recovery") {
            PropertyRow(title: "Recovery Model") {
                Picker("", selection: $recoveryModel) {
                    ForEach(SQLServerDatabaseOption.RecoveryModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(model)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: recoveryModel) { _, v in applyMSSQLOption(.recoveryModel(v)) }

            PropertyRow(title: "Page Verify") {
                Picker("", selection: $pageVerify) {
                    ForEach(SQLServerDatabaseOption.PageVerifyOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: pageVerify) { _, v in applyMSSQLOption(.pageVerify(v)) }

            PropertyRow(title: "Target Recovery Time", subtitle: "seconds") {
                TextField("", value: $targetRecoveryTime, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { applyMSSQLOption(.targetRecoveryTime(targetRecoveryTime)) }
            }

            PropertyRow(title: "Delayed Durability") {
                Picker("", selection: $delayedDurability) {
                    ForEach(SQLServerDatabaseOption.DelayedDurabilityOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: delayedDurability) { _, v in applyMSSQLOption(.delayedDurability(v)) }
        }

        Section("Compatibility") {
            PropertyRow(title: "Compatibility Level") {
                Picker("", selection: $compatibilityLevel) {
                    ForEach(compatibilityLevels, id: \.value) { level in
                        Text(level.label).tag(level.value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: compatibilityLevel) { _, v in applyMSSQLOption(.compatibilityLevel(v)) }
        }

        Section("State") {
            PropertyRow(title: "Read Only") {
                Toggle("", isOn: $isReadOnly)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: isReadOnly) { _, v in applyMSSQLOption(.readOnly(v)) }
            }

            PropertyRow(title: "User Access") {
                Picker("", selection: $userAccess) {
                    ForEach(SQLServerDatabaseOption.UserAccessOption.allCases, id: \.self) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: userAccess) { _, v in applyMSSQLOption(.userAccess(v)) }

            PropertyRow(title: "Encryption") {
                Toggle("", isOn: $isEncrypted)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: isEncrypted) { _, v in applyMSSQLOption(.encryption(v)) }
            }
        }

        Section("Isolation") {
            PropertyRow(title: "Allow Snapshot Isolation") {
                Toggle("", isOn: $allowSnapshotIsolation)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: allowSnapshotIsolation) { _, v in applyMSSQLOption(.allowSnapshotIsolation(v)) }
            }

            PropertyRow(title: "Read Committed Snapshot") {
                Toggle("", isOn: $readCommittedSnapshot)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: readCommittedSnapshot) { _, v in applyMSSQLOption(.readCommittedSnapshot(v)) }
            }
        }

        Section("Miscellaneous") {
            PropertyRow(title: "Broker Enabled") {
                Toggle("", isOn: $isBrokerEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: isBrokerEnabled) { _, v in applyMSSQLOption(.brokerEnabled(v)) }
            }

            PropertyRow(title: "Trustworthy") {
                Toggle("", isOn: $isTrustworthy)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: isTrustworthy) { _, v in applyMSSQLOption(.trustworthy(v)) }
            }

            PropertyRow(title: "Parameterization") {
                Picker("", selection: $parameterization) {
                    ForEach(SQLServerDatabaseOption.ParameterizationOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: parameterization) { _, v in applyMSSQLOption(.parameterization(v)) }
        }
    }

    @ViewBuilder
    func mssqlAutomaticPage() -> some View {
        Section("Statistics") {
            PropertyRow(title: "Auto Create Statistics") {
                Toggle("", isOn: $autoCreateStats)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: autoCreateStats) { _, v in applyMSSQLOption(.autoCreateStatistics(v)) }
            }

            PropertyRow(title: "Auto Update Statistics") {
                Toggle("", isOn: $autoUpdateStats)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: autoUpdateStats) { _, v in applyMSSQLOption(.autoUpdateStatistics(v)) }
            }

            PropertyRow(title: "Auto Update Stats Async") {
                Toggle("", isOn: $autoUpdateStatsAsync)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: autoUpdateStatsAsync) { _, v in applyMSSQLOption(.autoUpdateStatisticsAsync(v)) }
            }
        }

        Section("Storage") {
            PropertyRow(title: "Auto Close") {
                Toggle("", isOn: $autoClose)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: autoClose) { _, v in applyMSSQLOption(.autoClose(v)) }
            }

            PropertyRow(title: "Auto Shrink") {
                Toggle("", isOn: $autoShrink)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: autoShrink) { _, v in applyMSSQLOption(.autoShrink(v)) }
            }
        }
    }

    @ViewBuilder
    func mssqlAnsiPage() -> some View {
        Section("ANSI Defaults") {
            PropertyRow(title: "ANSI NULL Default") {
                Toggle("", isOn: $ansiNullDefault)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: ansiNullDefault) { _, v in applyMSSQLOption(.ansiNullDefault(v)) }
            }

            PropertyRow(title: "ANSI NULLS Enabled") {
                Toggle("", isOn: $ansiNulls)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: ansiNulls) { _, v in applyMSSQLOption(.ansiNulls(v)) }
            }

            PropertyRow(title: "ANSI Padding Enabled") {
                Toggle("", isOn: $ansiPadding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: ansiPadding) { _, v in applyMSSQLOption(.ansiPadding(v)) }
            }

            PropertyRow(title: "ANSI Warnings Enabled") {
                Toggle("", isOn: $ansiWarnings)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: ansiWarnings) { _, v in applyMSSQLOption(.ansiWarnings(v)) }
            }
        }

        Section("Arithmetic") {
            PropertyRow(title: "Arithmetic Abort Enabled") {
                Toggle("", isOn: $arithAbort)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: arithAbort) { _, v in applyMSSQLOption(.arithAbort(v)) }
            }

            PropertyRow(title: "Numeric Round-Abort") {
                Toggle("", isOn: $numericRoundAbort)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: numericRoundAbort) { _, v in applyMSSQLOption(.numericRoundAbort(v)) }
            }

            PropertyRow(title: "Concatenate Null Yields Null") {
                Toggle("", isOn: $concatNullYieldsNull)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: concatNullYieldsNull) { _, v in applyMSSQLOption(.concatNullYieldsNull(v)) }
            }
        }

        Section("Identifiers & Triggers") {
            PropertyRow(title: "Quoted Identifiers Enabled") {
                Toggle("", isOn: $quotedIdentifier)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: quotedIdentifier) { _, v in applyMSSQLOption(.quotedIdentifier(v)) }
            }

            PropertyRow(title: "Recursive Triggers Enabled") {
                Toggle("", isOn: $recursiveTriggers)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: recursiveTriggers) { _, v in applyMSSQLOption(.recursiveTriggers(v)) }
            }

            PropertyRow(title: "Date Correlation Optimization") {
                Toggle("", isOn: $dateCorrelation)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: dateCorrelation) { _, v in applyMSSQLOption(.dateCorrelationOptimization(v)) }
            }
        }
    }
}
