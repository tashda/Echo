import Foundation

extension MySQLDatabaseSecurityViewModel {

    // MARK: - Password Policies

    func loadPasswordPolicies() async {
        isLoadingPasswordPolicies = true
        defer { isLoadingPasswordPolicies = false }
        do {
            let result = try await session.simpleQuery("""
                SELECT Variable_name, Value FROM performance_schema.global_variables
                WHERE Variable_name IN (
                    'default_password_lifetime',
                    'password_history',
                    'password_reuse_interval',
                    'password_require_current',
                    'validate_password.policy',
                    'validate_password.length',
                    'validate_password.mixed_case_count',
                    'validate_password.number_count',
                    'validate_password.special_char_count',
                    'validate_password_policy',
                    'validate_password_length',
                    'validate_password_mixed_case_count',
                    'validate_password_number_count',
                    'validate_password_special_char_count',
                    'disconnect_on_expired_password',
                    'authentication_policy'
                )
                ORDER BY Variable_name
            """)
            passwordPolicies = result.rows.map { row in
                PasswordPolicyInfo(
                    id: row[safe: 0] ?? UUID().uuidString,
                    name: row[safe: 0] ?? "\u{2014}",
                    value: row[safe: 1] ?? "\u{2014}"
                )
            }
        } catch {
            panelState?.appendMessage("Failed to load password policies: \(error.localizedDescription)", severity: .error)
        }
    }

    func setPasswordPolicy(_ name: String, value: String) async {
        let handle = activityEngine?.begin("Updating \(name)", connectionSessionID: connectionSessionID)
        do {
            _ = try await session.simpleQuery("SET GLOBAL \(name) = \(value)")
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
        isLoadingMasking = true
        defer { isLoadingMasking = false }
        do {
            // Check if masking component is installed
            let check = try await session.simpleQuery("""
                SELECT COUNT(*) FROM information_schema.COMPONENTS
                WHERE COMPONENT_URN LIKE '%data_masking%'
            """)
            let installed = (check.rows.first?[safe: 0]).flatMap(Int.init) ?? 0

            if installed > 0 {
                let result = try await session.simpleQuery("""
                    SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, 'MASK' as FUNCTION
                    FROM information_schema.COLUMNS
                    WHERE GENERATION_EXPRESSION LIKE '%mask%'
                    ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
                    LIMIT 100
                """)
                maskingRules = result.rows.enumerated().map { idx, row in
                    MaskingRule(
                        id: "\(idx)",
                        schema: row[safe: 0] ?? "",
                        table: row[safe: 1] ?? "",
                        column: row[safe: 2] ?? "",
                        function: row[safe: 3] ?? "MASK"
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
        isLoadingEncryption = true
        defer { isLoadingEncryption = false }
        do {
            let result = try await session.simpleQuery("""
                SELECT Variable_name, Value FROM performance_schema.global_variables
                WHERE Variable_name IN (
                    'innodb_encrypt_tables',
                    'innodb_encrypt_log',
                    'innodb_redo_log_encrypt',
                    'innodb_undo_log_encrypt',
                    'table_encryption_privilege_check',
                    'default_table_encryption',
                    'keyring_file_data',
                    'early-plugin-load',
                    'binlog_encryption',
                    'encrypt_tmp_files',
                    'have_ssl',
                    'have_openssl',
                    'ssl_ca',
                    'ssl_cert',
                    'ssl_key',
                    'tls_version',
                    'tls_ciphersuites'
                )
                ORDER BY Variable_name
            """)

            var items = result.rows.map { row in
                EncryptionInfo(
                    id: row[safe: 0] ?? UUID().uuidString,
                    name: row[safe: 0] ?? "\u{2014}",
                    value: row[safe: 1] ?? "\u{2014}",
                    category: categorizeEncryptionVar(row[safe: 0] ?? "")
                )
            }

            // Add tablespace encryption status
            let tablespaceResult = try? await session.simpleQuery("""
                SELECT TABLE_SCHEMA, TABLE_NAME, CREATE_OPTIONS
                FROM information_schema.TABLES
                WHERE CREATE_OPTIONS LIKE '%ENCRYPTION%'
                ORDER BY TABLE_SCHEMA, TABLE_NAME
                LIMIT 50
            """)
            if let rows = tablespaceResult?.rows, !rows.isEmpty {
                items.append(EncryptionInfo(
                    id: "encrypted-tables-count",
                    name: "Encrypted Tables",
                    value: "\(rows.count) table(s)",
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
        isLoadingAudit = true
        defer { isLoadingAudit = false }
        do {
            // Check if audit plugin is installed
            let check = try await session.simpleQuery("""
                SELECT PLUGIN_STATUS FROM information_schema.PLUGINS
                WHERE PLUGIN_NAME = 'audit_log'
            """)
            auditPluginInstalled = !(check.rows.isEmpty)

            if auditPluginInstalled {
                // Try to read from audit log function (MySQL Enterprise)
                let result = try await session.simpleQuery("""
                    SELECT * FROM mysql.audit_log_filter LIMIT 50
                """)
                auditLogEntries = result.rows.enumerated().map { idx, row in
                    AuditLogEntry(
                        id: "\(idx)",
                        timestamp: row[safe: 0] ?? "\u{2014}",
                        user: row[safe: 1] ?? "",
                        host: "",
                        event: row[safe: 2] ?? "",
                        command: "",
                        query: ""
                    )
                }
            } else {
                // Fall back to general log for audit-like data
                let result = try? await session.simpleQuery("""
                    SELECT event_time, user_host, command_type, argument
                    FROM mysql.general_log
                    ORDER BY event_time DESC
                    LIMIT 50
                """)
                auditLogEntries = (result?.rows ?? []).enumerated().map { idx, row in
                    AuditLogEntry(
                        id: "general-\(idx)",
                        timestamp: row[safe: 0] ?? "\u{2014}",
                        user: row[safe: 1] ?? "",
                        host: "",
                        event: "Query",
                        command: row[safe: 2] ?? "",
                        query: row[safe: 3] ?? ""
                    )
                }
            }
        } catch {
            panelState?.appendMessage("Failed to load audit log: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - Firewall

    func loadFirewallRules() async {
        isLoadingFirewall = true
        defer { isLoadingFirewall = false }
        do {
            // Check if firewall plugin is installed
            let check = try await session.simpleQuery("""
                SELECT PLUGIN_STATUS FROM information_schema.PLUGINS
                WHERE PLUGIN_NAME = 'MYSQL_FIREWALL'
            """)
            firewallPluginInstalled = !(check.rows.isEmpty)

            if firewallPluginInstalled {
                let result = try await session.simpleQuery("""
                    SELECT USERHOST, RULE, MODE
                    FROM mysql.firewall_whitelist
                    ORDER BY USERHOST
                    LIMIT 100
                """)
                firewallRules = result.rows.enumerated().map { idx, row in
                    FirewallRule(
                        id: "\(idx)",
                        userhost: row[safe: 0] ?? "",
                        rule: row[safe: 1] ?? "",
                        mode: row[safe: 2] ?? ""
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
