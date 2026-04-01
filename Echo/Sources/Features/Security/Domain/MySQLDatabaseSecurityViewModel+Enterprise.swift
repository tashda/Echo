import Foundation
import MySQLKit

extension MySQLDatabaseSecurityViewModel {

    // MARK: - Password Policies

    func loadPasswordPolicies() async {
        guard let mysql = session as? MySQLSession else { return }
        isLoadingPasswordPolicies = true
        defer { isLoadingPasswordPolicies = false }
        do {
            let variables = try await mysql.client.security.passwordPolicyVariables()
            passwordPolicies = variables.map { variable in
                PasswordPolicyInfo(
                    id: variable.name,
                    name: variable.name,
                    value: variable.value
                )
            }
        } catch {
            panelState?.appendMessage("Failed to load password policies: \(error.localizedDescription)", severity: .error)
        }
    }

    func setPasswordPolicy(_ name: String, value: String) async {
        guard let mysql = session as? MySQLSession else { return }
        let handle = activityEngine?.begin("Updating \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try await mysql.client.serverConfig.setGlobalVariable(name, to: value)
            handle?.succeed()
            panelState?.appendMessage("Updated \(name) = \(value)")
            await loadPasswordPolicies()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to update \(name): \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Data Masking

    func loadMaskingRules() async {
        guard let mysql = session as? MySQLSession else { return }
        isLoadingMasking = true
        defer { isLoadingMasking = false }
        do {
            let installed = try await mysql.client.security.maskingComponentInstalled()
            if installed {
                let rules = try await mysql.client.security.maskingRules()
                maskingRules = rules.enumerated().map { idx, rule in
                    MaskingRule(
                        id: "\(idx)",
                        schema: rule.schema,
                        table: rule.table,
                        column: rule.column,
                        function: rule.function
                    )
                }
            } else {
                maskingRules = []
            }
        } catch {
            maskingRules = []
            panelState?.appendMessage("Data masking component not available: \(error.localizedDescription)", severity: .info)
        }
    }

    // MARK: - Encryption

    func loadEncryptionInfo() async {
        guard let mysql = session as? MySQLSession else { return }
        isLoadingEncryption = true
        defer { isLoadingEncryption = false }
        do {
            let variables = try await mysql.client.security.encryptionVariables()
            var items = variables.map { variable in
                EncryptionInfo(
                    id: variable.name,
                    name: variable.name,
                    value: variable.value,
                    category: categorizeEncryptionVar(variable.name)
                )
            }

            let encryptedTables = try? await mysql.client.security.encryptedTables()
            if let tables = encryptedTables, !tables.isEmpty {
                items.append(EncryptionInfo(
                    id: "encrypted-tables-count",
                    name: "Encrypted Tables",
                    value: "\(tables.count) table(s)",
                    category: "Tablespace"
                ))
            }

            encryptionInfo = items
        } catch {
            panelState?.appendMessage("Failed to load encryption info: \(error.localizedDescription)", severity: .error)
        }
    }

    private func categorizeEncryptionVar(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("ssl") || lower.contains("tls") { return "TLS/SSL" }
        if lower.contains("keyring") { return "Keyring" }
        if lower.contains("innodb") { return "InnoDB" }
        if lower.contains("binlog") { return "Binary Log" }
        return "General"
    }

    // MARK: - Audit Log

    func loadAuditLog() async {
        guard let mysql = session as? MySQLSession else { return }
        isLoadingAudit = true
        defer { isLoadingAudit = false }
        do {
            auditPluginInstalled = try await mysql.client.security.auditPluginInstalled()

            if auditPluginInstalled {
                let filters = try await mysql.client.security.auditLogFilters()
                auditLogEntries = filters.enumerated().map { idx, filter in
                    AuditLogEntry(
                        id: "\(idx)",
                        timestamp: filter.filterName,
                        user: filter.definition ?? "",
                        host: "",
                        event: "Filter",
                        command: "",
                        query: ""
                    )
                }
            } else {
                let entries = try? await mysql.client.security.generalLogEntries()
                auditLogEntries = (entries ?? []).enumerated().map { idx, entry in
                    AuditLogEntry(
                        id: "general-\(idx)",
                        timestamp: entry.eventTime ?? "\u{2014}",
                        user: entry.userHost ?? "",
                        host: "",
                        event: "Query",
                        command: entry.commandType ?? "",
                        query: entry.argument ?? ""
                    )
                }
            }
        } catch {
            panelState?.appendMessage("Failed to load audit log: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Firewall

    func loadFirewallRules() async {
        guard let mysql = session as? MySQLSession else { return }
        isLoadingFirewall = true
        defer { isLoadingFirewall = false }
        do {
            firewallPluginInstalled = try await mysql.client.security.firewallPluginInstalled()

            if firewallPluginInstalled {
                let rules = try await mysql.client.security.firewallRules()
                firewallRules = rules.enumerated().map { idx, rule in
                    FirewallRule(
                        id: "\(idx)",
                        userhost: rule.userhost,
                        rule: rule.rule,
                        mode: rule.mode
                    )
                }
            } else {
                firewallRules = []
            }
        } catch {
            firewallRules = []
            panelState?.appendMessage("Firewall plugin not available: \(error.localizedDescription)", severity: .info)
        }
    }
}
