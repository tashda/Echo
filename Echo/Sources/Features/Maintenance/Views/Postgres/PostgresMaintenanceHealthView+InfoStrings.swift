import SwiftUI

extension PostgresMaintenanceHealthView {

    func cacheHitInfo(_ ratio: Double?) -> String {
        let base = "Percentage of data reads served from shared buffers."
        guard let ratio else { return base }
        if ratio >= 99 { return "\(base) Current ratio is excellent." }
        if ratio >= 95 { return "\(base)\n\nAction: Consider increasing shared_buffers in postgresql.conf. Current ratio suggests some reads are hitting disk." }
        return "\(base)\n\nAction: Increase shared_buffers significantly. Current ratio indicates heavy disk I/O. Also check for sequential scans on large tables (add missing indexes)."
    }

    func connectionInfo(_ health: PostgresMaintenanceHealth) -> String {
        let base = "Active connections vs max_connections."
        if health.connectionUsagePercent > 80 {
            return "\(base)\n\nAction: Connection usage is critically high. Consider using a connection pooler (PgBouncer) or increasing max_connections. Investigate idle connections that should be closed."
        }
        if health.connectionUsagePercent > 60 {
            return "\(base)\n\nAction: Connection usage is elevated. Monitor for leaking connections. Consider a connection pooler if usage continues to grow."
        }
        return "\(base) Current usage is healthy."
    }

    func deadTupleInfo(_ backlog: Int64) -> String {
        let base = "Total dead tuples across all tables."
        if backlog > 1_000_000 {
            return "\(base)\n\nAction: Autovacuum is significantly behind. Check for long-running transactions blocking vacuum (Oldest Transaction above). Consider running VACUUM manually on the largest tables, or tuning autovacuum_vacuum_cost_delay and autovacuum_vacuum_scale_factor."
        }
        if backlog > 100_000 {
            return "\(base)\n\nAction: Autovacuum may be falling behind. Check autovacuum settings and look for tables with high dead tuple counts in the Tables tab."
        }
        return "\(base) Current backlog is manageable."
    }

    func oldestTxInfo(_ seconds: Int64) -> String {
        let base = "Long-running transactions prevent autovacuum from reclaiming dead tuples."
        if seconds > 3600 {
            return "\(base)\n\nAction: A transaction has been open for over an hour. This blocks vacuum across all tables. Identify and terminate the idle session using pg_terminate_backend(), or investigate why the application is holding a transaction open."
        }
        if seconds > 300 {
            return "\(base)\n\nAction: A transaction has been running for several minutes. Monitor it — if idle, consider terminating it to unblock autovacuum."
        }
        return "\(base) No concerning long-running transactions."
    }

    func txidInfo(_ health: PostgresMaintenanceHealth) -> String {
        let base = "PostgreSQL must vacuum tables before their transaction ID age reaches 2 billion. At that point the database shuts down to prevent data corruption."
        switch health.txidSeverity {
        case .critical:
            return "\(base)\n\nAction: CRITICAL — Transaction ID age is dangerously high. Run VACUUM FREEZE immediately on tables with the highest age (check the Age column in the Tables tab). If autovacuum is blocked by long transactions, terminate them first."
        case .warning:
            return "\(base)\n\nAction: Transaction ID age is elevated. Ensure autovacuum is running and not blocked. Check tables with high age in the Tables tab and consider running VACUUM FREEZE on them."
        case .healthy:
            return "\(base) Current age is healthy."
        }
    }

    func checkpointInfo(_ bg: PostgresMaintenanceHealth.BGWriterStats) -> String {
        let base = "Timed checkpoints run on schedule. Requested checkpoints are forced by heavy write activity."
        if bg.checkpointsRequested > bg.checkpointsTimed {
            return "\(base)\n\nAction: More checkpoints are being forced than scheduled. Increase checkpoint_completion_target (to 0.9) and max_wal_size to allow longer intervals between checkpoints."
        }
        return "\(base) Current ratio is normal."
    }

    func buffersInfo(_ bg: PostgresMaintenanceHealth.BGWriterStats) -> String {
        let base = "Buffers written by the checkpointer, background writer, and client backends."
        if bg.buffersBackend > bg.buffersCheckpoint {
            return "\(base)\n\nAction: Backends are writing more buffers than the checkpointer, indicating the background writer can't keep up. Increase bgwriter_lru_maxpages and bgwriter_lru_multiplier to write dirty pages more aggressively."
        }
        return "\(base) Buffer write distribution is healthy."
    }
}
