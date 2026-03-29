import SwiftUI

// MARK: - Password Policies Section

struct MySQLPasswordPoliciesSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

    var body: some View {
        if viewModel.isLoadingPasswordPolicies {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.passwordPolicies.isEmpty {
            ContentUnavailableView {
                Label("Password Policies", systemImage: "lock.shield")
            } description: {
                Text("No password policy variables found. The validate_password component may not be installed.")
            } actions: {
                Button("Install Component") {
                    Task {
                        _ = try? await viewModel.session.simpleQuery("INSTALL COMPONENT 'file://component_validate_password'")
                        await viewModel.loadPasswordPolicies()
                    }
                }
            }
        } else {
            Table(viewModel.passwordPolicies) {
                TableColumn("Policy") { item in
                    Text(item.name)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 220, ideal: 300)

                TableColumn("Value") { item in
                    Text(item.value)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
                .width(min: 140, ideal: 200)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

// MARK: - Data Masking Section

struct MySQLDataMaskingSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

    var body: some View {
        if viewModel.isLoadingMasking {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.maskingRules.isEmpty {
            ContentUnavailableView {
                Label("Data Masking", systemImage: "eye.slash")
            } description: {
                Text("No masking rules found. The MySQL data masking component may not be installed.")
            } actions: {
                Button("Install Component") {
                    Task {
                        _ = try? await viewModel.session.simpleQuery("INSTALL COMPONENT 'file://component_masking'")
                        await viewModel.loadMaskingRules()
                    }
                }
            }
        } else {
            Table(viewModel.maskingRules) {
                TableColumn("Schema") { rule in
                    Text(rule.schema)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Table") { rule in
                    Text(rule.table)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Column") { rule in
                    Text(rule.column)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Function") { rule in
                    Text(rule.function)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

// MARK: - Encryption Section

struct MySQLEncryptionSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

    var body: some View {
        if viewModel.isLoadingEncryption {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.encryptionInfo.isEmpty {
            ContentUnavailableView {
                Label("Encryption", systemImage: "lock.fill")
            } description: {
                Text("No encryption configuration found.")
            }
        } else {
            Table(viewModel.encryptionInfo) {
                TableColumn("Setting") { item in
                    Text(item.name)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 200, ideal: 280)

                TableColumn("Value") { item in
                    Text(item.value)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .textSelection(.enabled)
                }
                .width(min: 140, ideal: 200)

                TableColumn("Category") { item in
                    Text(item.category)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
                .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

// MARK: - Audit Log Section

struct MySQLAuditSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

    var body: some View {
        if viewModel.isLoadingAudit {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.auditPluginInstalled && viewModel.auditLogEntries.isEmpty {
            ContentUnavailableView {
                Label("Audit Log", systemImage: "list.clipboard")
            } description: {
                Text("The MySQL audit_log plugin is not installed. Showing general log entries as a fallback.")
            } actions: {
                Button("Enable General Log") {
                    Task {
                        _ = try? await viewModel.session.simpleQuery("SET GLOBAL general_log = 'ON'")
                        _ = try? await viewModel.session.simpleQuery("SET GLOBAL log_output = 'TABLE'")
                        await viewModel.loadAuditLog()
                    }
                }
            }
        } else {
            Table(viewModel.auditLogEntries) {
                TableColumn("Timestamp") { entry in
                    Text(entry.timestamp)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 140, ideal: 180)

                TableColumn("User") { entry in
                    Text(entry.user)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Command") { entry in
                    Text(entry.command)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Query") { entry in
                    Text(entry.query)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .width(min: 200, ideal: 400)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

// MARK: - Firewall Section

struct MySQLFirewallSection: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

    var body: some View {
        if viewModel.isLoadingFirewall {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.firewallPluginInstalled {
            ContentUnavailableView {
                Label("Firewall", systemImage: "flame")
            } description: {
                Text("The MySQL Enterprise Firewall plugin is not installed on this server.")
            }
        } else if viewModel.firewallRules.isEmpty {
            ContentUnavailableView {
                Label("No Firewall Rules", systemImage: "flame")
            } description: {
                Text("No firewall whitelist rules have been configured.")
            }
        } else {
            Table(viewModel.firewallRules) {
                TableColumn("User@Host") { rule in
                    Text(rule.userhost)
                        .font(TypographyTokens.Table.name)
                }
                .width(min: 140, ideal: 200)

                TableColumn("Rule") { rule in
                    Text(rule.rule)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                .width(min: 200, ideal: 400)

                TableColumn("Mode") { rule in
                    Text(rule.mode)
                        .font(TypographyTokens.Table.secondaryName)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .width(min: 80, ideal: 100)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}
