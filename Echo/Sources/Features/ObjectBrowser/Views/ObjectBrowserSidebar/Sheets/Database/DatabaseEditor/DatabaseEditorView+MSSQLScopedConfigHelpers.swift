import SwiftUI
import SQLServerKit

// MARK: - Scoped Configuration Helpers

extension DatabaseEditorView {

    enum ScopedConfigControlType {
        case toggle(isOn: Bool)
        case picker(options: [String])
        case numeric
        case readOnly
    }

    func scopedConfigControlType(_ config: SQLServerScopedConfiguration) -> ScopedConfigControlType {
        let name = config.name.uppercased()
        let value = config.value.uppercased()

        // Enum pickers
        if name == "ELEVATE_ONLINE" || name == "ELEVATE_RESUMABLE" {
            return .picker(options: ["OFF", "WHEN_SUPPORTED", "FAIL_UNSUPPORTED"])
        }

        // Numeric values
        if name == "MAXDOP" || name == "PAUSED_RESUMABLE_INDEX_ABORT_DURATION_MINUTES" || name == "DW_COMPATIBILITY_LEVEL" || name == "FULLTEXT_INDEX_VERSION" {
            return .numeric
        }

        // Boolean ON/OFF or 0/1
        if value == "ON" || value == "OFF" || value == "0" || value == "1" {
            let isOn = value == "ON" || value == "1"
            return .toggle(isOn: isOn)
        }

        return .readOnly
    }

    func scopedConfigToggleBinding(_ config: SQLServerScopedConfiguration, currentlyOn: Bool) -> Binding<Bool> {
        Binding(
            get: {
                let val = self.viewModel.scopedConfigurations.first(where: { $0.configurationID == config.configurationID })?.value.uppercased() ?? ""
                return val == "ON" || val == "1"
            },
            set: { newValue in
                let newVal = newValue ? "ON" : "OFF"
                self.viewModel.updateScopedConfigValue(configurationID: config.configurationID, newValue: newVal)
            }
        )
    }

    func scopedConfigPickerBinding(_ config: SQLServerScopedConfiguration) -> Binding<String> {
        Binding(
            get: {
                self.viewModel.scopedConfigurations.first(where: { $0.configurationID == config.configurationID })?.value ?? config.value
            },
            set: { newValue in
                self.viewModel.updateScopedConfigValue(configurationID: config.configurationID, newValue: newValue)
            }
        )
    }

    func scopedConfigDescription(_ name: String) -> String {
        switch name.uppercased() {
        case "ACCELERATED_PLAN_FORCING":
            return "Enables an optimized mechanism for query plan forcing, applicable to Query Store forced plans and USE PLAN hints."
        case "ASYNC_STATS_UPDATE_WAIT_AT_LOW_PRIORITY":
            return "Background statistics updates wait for schema locks on a low-priority queue, avoiding blocking in high-concurrency scenarios."
        case "BATCH_MODE_ADAPTIVE_JOINS":
            return "Enables adaptive joins that choose between hash and nested loop joins at runtime based on actual row counts."
        case "BATCH_MODE_MEMORY_GRANT_FEEDBACK":
            return "Adjusts memory grants for repeated queries based on actual memory usage from previous executions."
        case "BATCH_MODE_ON_ROWSTORE":
            return "Enables batch mode execution for rowstore queries, improving analytical query performance without columnstore indexes."
        case "CE_FEEDBACK":
            return "Automatically corrects cardinality estimation model assumptions using Query Store feedback. Requires Query Store in READ_WRITE mode."
        case "DEFERRED_COMPILATION_TV":
            return "Defers table variable compilation until first execution, allowing the optimizer to use actual row counts instead of assuming 1 row."
        case "DOP_FEEDBACK":
            return "Automatically identifies and lowers the degree of parallelism for queries where excessive parallelism wastes resources."
        case "DW_COMPATIBILITY_LEVEL":
            return "Sets the T-SQL and query processing compatibility level for Azure Synapse Analytics workloads."
        case "ELEVATE_ONLINE":
            return "Automatically elevates supported DDL operations (index rebuild, alter column) to ONLINE execution to reduce blocking."
        case "ELEVATE_RESUMABLE":
            return "Automatically elevates supported DDL operations to RESUMABLE execution, allowing pause and resume of long-running operations."
        case "EXEC_QUERY_STATS_FOR_SCALAR_FUNCTIONS":
            return "Controls whether execution statistics are collected for scalar user-defined functions in sys.dm_exec_function_stats."
        case "FULLTEXT_INDEX_VERSION":
            return "Sets the full-text index version used for new or rebuilt indexes. Version 2 uses newer components with improved word-breaking."
        case "IDENTITY_CACHE":
            return "Caches identity values for INSERT performance. Disabling prevents identity gaps after unexpected server restart or failover."
        case "INTERLEAVED_EXECUTION_TVF":
            return "Enables interleaved execution for multi-statement table-valued functions, improving cardinality estimates for downstream operators."
        case "ISOLATE_SECURITY_POLICY_CARDINALITY":
            return "Prevents row-level security filter predicates from affecting the query plan's cardinality estimates."
        case "GLOBAL_TEMPORARY_TABLE_AUTO_DROP":
            return "Automatically drops global temporary tables when no session is using them. Disable to keep them available across sessions."
        case "LAST_QUERY_PLAN_STATS":
            return "Enables collection of the last actual execution plan statistics, viewable via sys.dm_exec_query_plan_stats."
        case "LEGACY_CARDINALITY_ESTIMATION":
            return "Uses the SQL Server 2012 and earlier cardinality estimation model. Useful when newer CE produces suboptimal plans for specific workloads."
        case "LIGHTWEIGHT_QUERY_PROFILING":
            return "Enables the lightweight query profiling infrastructure for efficient collection of per-operator execution statistics."
        case "MAXDOP":
            return "Sets the default maximum degree of parallelism for queries in this database. 0 uses the server-wide setting."
        case "MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT":
            return "Uses percentile-based memory grant calculations to improve memory grant accuracy for repeated queries."
        case "MEMORY_GRANT_FEEDBACK_PERSISTENCE":
            return "Persists memory grant feedback adjustments in Query Store so they survive cache eviction and server restarts."
        case "OPTIMIZE_FOR_AD_HOC_WORKLOADS":
            return "Stores a compiled plan stub on first execution instead of the full plan, saving memory for queries that run only once."
        case "OPTIMIZED_PLAN_FORCING":
            return "Reduces compilation overhead for repeatedly forced queries by caching optimization replay scripts in Query Store."
        case "OPTIMIZED_SP_EXECUTESQL":
            return "Serializes compilation for identical sp_executesql calls, reducing compilation storms under high concurrency."
        case "PARAMETER_SENSITIVE_PLAN_OPTIMIZATION":
            return "Generates multiple plan variants for queries with parameters that have non-uniform data distributions."
        case "PARAMETER_SNIFFING":
            return "Uses parameter values from the first execution to optimize the query plan. Disabling uses average distribution statistics instead."
        case "PAUSED_RESUMABLE_INDEX_ABORT_DURATION_MINUTES":
            return "Minutes a paused resumable index operation waits before being automatically aborted. 0 means never auto-abort."
        case "QUERY_OPTIMIZER_HOTFIXES":
            return "Enables query optimizer bug fixes released after the database's compatibility level, regardless of trace flag 4199."
        case "ROW_MODE_MEMORY_GRANT_FEEDBACK":
            return "Adjusts memory grants for row mode queries based on actual usage from previous executions."
        case "TSQL_SCALAR_UDF_INLINING":
            return "Inlines scalar user-defined functions into the calling query for improved performance. Requires compatibility level 150+."
        case "VERBOSE_TRUNCATION_WARNINGS":
            return "Shows the actual column name and truncated value in 'string or binary data would be truncated' errors."
        case "XTP_PROCEDURE_EXECUTION_STATISTICS":
            return "Collects execution statistics for natively compiled In-Memory OLTP stored procedures. High overhead — use for troubleshooting only."
        case "XTP_QUERY_EXECUTION_STATISTICS":
            return "Collects per-statement execution statistics for natively compiled In-Memory OLTP modules. High overhead — use for troubleshooting only."
        default:
            return "Database scoped configuration option."
        }
    }
}
