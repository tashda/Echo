#!/usr/bin/env swift

import Foundation
import PostgresWire
import Logging

// Set up logging
var logger = Logger(label: "performance-test")
logger.logLevel = .debug

// Load environment variables
let config = PostgresWireConfiguration(
    host: "tippr.dk",
    port: 5432,
    username: "rundeckuser",
    password: "3On4d70tUjhvZAPfsmR6rohWVJgRdNXMvGFeLtdvZt2B1P",
    database: "tippr",
    useTLS: false,
    applicationName: "performance-test"
)

let testQuery = "SELECT * FROM public.fixture LIMIT 100000;"

func measureTime<T>(operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
    let start = CFAbsoluteTimeGetCurrent()
    let result = try await operation()
    let time = CFAbsoluteTimeGetCurrent() - start
    return (result, time)
}

@main
struct PerformanceTest {
    static func main() async throws {
        print("🚀 Starting PostgreSQL Performance Test")
        print("📊 Query: \(testQuery)")
        print("")

        do {
            // Test connection
            let (client, connectTime) = try await measureTime {
                try await PostgresDatabaseClient.connect(configuration: config.makeWireConfiguration(), logger: logger)
            }
            print("✅ Connected in \(String(format: "%.3f", connectTime))s")

            // Test query execution
            print("🔄 Executing query...")
            let (rows, queryTime) = try await measureTime {
                var rowCount = 0
                let rowSequence = try await client.simpleQuery(testQuery)

                for try await _ in rowSequence {
                    rowCount += 1
                    // Print progress every 10k rows
                    if rowCount % 10000 == 0 {
                        print("   📈 Processed \(rowCount) rows...")
                    }
                }
                return rowCount
            }

            print("✅ Query completed!")
            print("📊 Total rows: \(rows)")
            print("⏱️  Total time: \(String(format: "%.3f", queryTime))s")
            print("🎯 Target: < 12.0s")

            if queryTime < 12.0 {
                print("🎉 PERFORMANCE TARGET MET!")
            } else {
                print("⚠️  Performance target NOT met. Need optimization.")
                let overhead = queryTime - 17.043  // psql baseline
                print("📈 App overhead vs psql: \(String(format: "%.3f", overhead))s")
            }

            client.close()

        } catch {
            print("❌ Error: \(error)")
        }
    }
}

// Helper extension
extension PostgresConfiguration {
    func makeWireConfiguration() -> PostgresWireConfiguration {
        return PostgresWireConfiguration(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            useTLS: useTLS,
            applicationName: applicationName
        )
    }
}