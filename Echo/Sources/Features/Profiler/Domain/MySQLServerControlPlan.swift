import Foundation

struct MySQLServerControlProcessPlan: Sendable, Equatable {
    let executable: URL
    let arguments: [String]
    let environment: [String: String]
}

enum MySQLServerRestartPlan: Sendable, Equatable {
    case single(MySQLServerControlProcessPlan)
    case stopThenStart(stop: MySQLServerControlProcessPlan, start: MySQLServerControlProcessPlan)
}

enum MySQLServerControlPlan {
    static func stop(
        host: String,
        port: Int,
        username: String,
        password: String?,
        customToolPath: String?
    ) -> MySQLServerControlProcessPlan? {
        guard let mysqladmin = MySQLToolLocator.mysqladminURL(customPath: customToolPath) else {
            return nil
        }

        return MySQLServerControlProcessPlan(
            executable: mysqladmin,
            arguments: [
                "--host=\(host)",
                "--port=\(port)",
                "--user=\(username)",
                "shutdown",
            ],
            environment: password.map { ["MYSQL_PWD": $0] } ?? [:]
        )
    }

    static func start(customToolPath: String?, defaultsFilePath: String?) -> MySQLServerControlProcessPlan? {
        if let script = MySQLToolLocator.mysqlServerScriptURL(customPath: customToolPath) {
            return MySQLServerControlProcessPlan(
                executable: script,
                arguments: ["start"],
                environment: [:]
            )
        }

        if let mysqld = MySQLToolLocator.mysqldURL(customPath: customToolPath) {
            var arguments: [String] = []
            if let defaultsFilePath, !defaultsFilePath.isEmpty {
                arguments.append("--defaults-file=\(defaultsFilePath)")
            }
            arguments.append("--daemonize")

            return MySQLServerControlProcessPlan(
                executable: mysqld,
                arguments: arguments,
                environment: [:]
            )
        }

        return nil
    }

    static func restart(
        host: String,
        port: Int,
        username: String,
        password: String?,
        customToolPath: String?,
        defaultsFilePath: String?
    ) -> MySQLServerRestartPlan? {
        if let script = MySQLToolLocator.mysqlServerScriptURL(customPath: customToolPath) {
            return .single(
                MySQLServerControlProcessPlan(
                    executable: script,
                    arguments: ["restart"],
                    environment: [:]
                )
            )
        }

        guard let stop = stop(
            host: host,
            port: port,
            username: username,
            password: password,
            customToolPath: customToolPath
        ), let start = start(customToolPath: customToolPath, defaultsFilePath: defaultsFilePath) else {
            return nil
        }

        return .stopThenStart(stop: stop, start: start)
    }
}
