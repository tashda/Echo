import Foundation

struct PostgresServerControlPlan {
    static func stop(dataDir: String?, customToolPath: String?) -> MySQLServerControlProcessPlan? {
        guard let pgCtl = PostgresToolLocator.pgCtlURL(customPath: customToolPath) else {
            return nil
        }

        var arguments = ["stop"]
        if let dataDir, !dataDir.isEmpty {
            arguments.append(contentsOf: ["-D", dataDir])
        }
        arguments.append(contentsOf: ["-m", "fast"])

        return MySQLServerControlProcessPlan(
            executable: pgCtl,
            arguments: arguments,
            environment: [:]
        )
    }

    static func start(dataDir: String?, customToolPath: String?, logFile: String? = nil) -> MySQLServerControlProcessPlan? {
        guard let pgCtl = PostgresToolLocator.pgCtlURL(customPath: customToolPath) else {
            return nil
        }

        var arguments = ["start"]
        if let dataDir, !dataDir.isEmpty {
            arguments.append(contentsOf: ["-D", dataDir])
        }
        if let logFile, !logFile.isEmpty {
            arguments.append(contentsOf: ["-l", logFile])
        }

        return MySQLServerControlProcessPlan(
            executable: pgCtl,
            arguments: arguments,
            environment: [:]
        )
    }

    static func restart(dataDir: String?, customToolPath: String?, logFile: String? = nil) -> MySQLServerControlProcessPlan? {
        guard let pgCtl = PostgresToolLocator.pgCtlURL(customPath: customToolPath) else {
            return nil
        }

        var arguments = ["restart"]
        if let dataDir, !dataDir.isEmpty {
            arguments.append(contentsOf: ["-D", dataDir])
        }
        if let logFile, !logFile.isEmpty {
            arguments.append(contentsOf: ["-l", logFile])
        }
        arguments.append(contentsOf: ["-m", "fast"])

        return MySQLServerControlProcessPlan(
            executable: pgCtl,
            arguments: arguments,
            environment: [:]
        )
    }

    static func status(dataDir: String?, customToolPath: String?) -> MySQLServerControlProcessPlan? {
        guard let pgCtl = PostgresToolLocator.pgCtlURL(customPath: customToolPath) else {
            return nil
        }

        var arguments = ["status"]
        if let dataDir, !dataDir.isEmpty {
            arguments.append(contentsOf: ["-D", dataDir])
        }

        return MySQLServerControlProcessPlan(
            executable: pgCtl,
            arguments: arguments,
            environment: [:]
        )
    }
}
