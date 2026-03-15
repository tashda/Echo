import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL date and time data type round-trips through Echo's DatabaseSession layer.
final class PGDataTypeDateTimeTests: PostgresDockerTestCase {

    // MARK: - Date

    func testDateLiteral() async throws {
        let result = try await query("SELECT '2024-03-15'::DATE AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("2024") ?? false)
    }

    func testDateMinValue() async throws {
        let result = try await query("SELECT '0001-01-01'::DATE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testDateFarFuture() async throws {
        let result = try await query("SELECT '9999-12-31'::DATE AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("9999") ?? false)
    }

    func testDateCurrentDate() async throws {
        let result = try await query("SELECT CURRENT_DATE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testDateLeapYear() async throws {
        let result = try await query("SELECT '2024-02-29'::DATE AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("02-29") ?? false ||
                      result.rows[0][0]?.contains("02/29") ?? false)
    }

    // MARK: - Time

    func testTimeBasic() async throws {
        let result = try await query("SELECT '14:30:00'::TIME AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("14:30") ?? false)
    }

    func testTimeMidnight() async throws {
        let result = try await query("SELECT '00:00:00'::TIME AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("00:00") ?? false)
    }

    func testTimeWithMicroseconds() async throws {
        let result = try await query("SELECT '14:30:00.123456'::TIME AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("14:30") ?? false)
    }

    func testTimeEndOfDay() async throws {
        let result = try await query("SELECT '23:59:59.999999'::TIME AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("23:59") ?? false)
    }

    // MARK: - Time with Time Zone

    func testTimetzBasic() async throws {
        let result = try await query("SELECT '14:30:00+05:30'::TIMETZ AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("14:30") ?? false)
    }

    func testTimetzUTC() async throws {
        let result = try await query("SELECT '14:30:00+00'::TIMETZ AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testTimetzNegativeOffset() async throws {
        let result = try await query("SELECT '10:00:00-07:00'::TIMETZ AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Timestamp

    func testTimestampBasic() async throws {
        let result = try await query("SELECT '2024-03-15 14:30:00'::TIMESTAMP AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("2024") ?? false)
    }

    func testTimestampWithMicroseconds() async throws {
        let result = try await query("SELECT '2024-03-15 14:30:00.123456'::TIMESTAMP AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testTimestampNow() async throws {
        let result = try await query("SELECT NOW()::TIMESTAMP AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testTimestampEpoch() async throws {
        let result = try await query("SELECT 'epoch'::TIMESTAMP AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("1970") ?? false)
    }

    // MARK: - Timestamp with Time Zone

    func testTimestamptzBasic() async throws {
        let result = try await query("SELECT '2024-03-15 14:30:00+00'::TIMESTAMPTZ AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testTimestamptzDifferentZones() async throws {
        let result = try await query("""
            SELECT '2024-03-15 14:30:00+05:30'::TIMESTAMPTZ AS ist,
                   '2024-03-15 14:30:00-05:00'::TIMESTAMPTZ AS est
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
        // Different timezone representations of different actual times
        XCTAssertNotEqual(result.rows[0][0], result.rows[0][1])
    }

    func testTimestamptzNow() async throws {
        let result = try await query("SELECT NOW() AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testTimestamptzEpoch() async throws {
        let result = try await query("SELECT 'epoch'::TIMESTAMPTZ AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Interval

    func testIntervalBasic() async throws {
        let result = try await query("SELECT '1 year 2 months 3 days 4 hours'::INTERVAL AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testIntervalDays() async throws {
        let result = try await query("SELECT '30 days'::INTERVAL AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testIntervalHoursMinutesSeconds() async throws {
        let result = try await query("SELECT '04:30:15'::INTERVAL AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testIntervalNegative() async throws {
        let result = try await query("SELECT '-3 hours'::INTERVAL AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testIntervalZero() async throws {
        let result = try await query("SELECT '0'::INTERVAL AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testIntervalComplex() async throws {
        let result = try await query("""
            SELECT '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'::INTERVAL AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
    }

    func testIntervalArithmetic() async throws {
        let result = try await query("""
            SELECT ('2024-03-15'::DATE + '10 days'::INTERVAL)::DATE AS future_date
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("2024-03-25") ?? false)
    }

    // MARK: - Special Values

    func testDateInfinity() async throws {
        let result = try await query("SELECT 'infinity'::TIMESTAMP AS pos, '-infinity'::TIMESTAMP AS neg")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
        let posStr = result.rows[0][0]!.lowercased()
        let negStr = result.rows[0][1]!.lowercased()
        XCTAssertTrue(posStr.contains("infinity"), "Expected infinity, got \(posStr)")
        XCTAssertTrue(negStr.contains("infinity"), "Expected -infinity, got \(negStr)")
    }

    func testTimestamptzInfinity() async throws {
        let result = try await query("""
            SELECT 'infinity'::TIMESTAMPTZ AS pos, '-infinity'::TIMESTAMPTZ AS neg
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    func testDateEpoch() async throws {
        let result = try await query("SELECT 'epoch'::TIMESTAMP AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("1970-01-01") ?? false)
    }

    // MARK: - NULL Handling

    func testNullDate() async throws {
        let result = try await query("SELECT NULL::DATE AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullTime() async throws {
        let result = try await query("SELECT NULL::TIME AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullTimetz() async throws {
        let result = try await query("SELECT NULL::TIMETZ AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullTimestamp() async throws {
        let result = try await query("SELECT NULL::TIMESTAMP AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullTimestamptz() async throws {
        let result = try await query("SELECT NULL::TIMESTAMPTZ AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullInterval() async throws {
        let result = try await query("SELECT NULL::INTERVAL AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullAllDateTimeTypes() async throws {
        let result = try await query("""
            SELECT NULL::DATE AS d, NULL::TIME AS t, NULL::TIMETZ AS tz,
                   NULL::TIMESTAMP AS ts, NULL::TIMESTAMPTZ AS tstz, NULL::INTERVAL AS i
        """)
        for col in 0..<6 {
            XCTAssertNil(result.rows[0][col], "Column \(col) should be NULL")
        }
    }

    // MARK: - Table Round-Trip

    func testDateTimeRoundTripAllTypes() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .date(name: "date_val"),
            .time(name: "time_val"),
            .timeWithTimeZone(name: "timetz_val"),
            .timestamp(name: "ts_val"),
            .timestampWithTimeZone(name: "tstz_val"),
            PostgresColumnDefinition(name: "interval_val", dataType: "INTERVAL")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["date_val", "time_val", "timetz_val", "ts_val", "tstz_val", "interval_val"],
            values: [[
                PostgresInsertValue.sql("'2024-06-15'"),
                PostgresInsertValue.sql("'10:30:00'"),
                PostgresInsertValue.sql("'10:30:00+02:00'"),
                PostgresInsertValue.sql("'2024-06-15 10:30:00'"),
                PostgresInsertValue.sql("'2024-06-15 10:30:00+00'"),
                PostgresInsertValue.sql("'1 year 2 months 3 days'")
            ]]
        )

        let result = try await query("SELECT * FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.columns.count, 7)

        // All values should be non-null
        for (i, col) in result.columns.enumerated() {
            XCTAssertNotNil(result.rows[0][i], "Column \(col.name) should have a value")
        }
    }

    func testDateTimeRoundTripWithNulls() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .date(name: "date_val"),
            .time(name: "time_val"),
            .timestamp(name: "ts_val")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["date_val", "time_val", "ts_val"],
            values: [[PostgresInsertValue.null, PostgresInsertValue.null, PostgresInsertValue.null]]
        )

        let result = try await query("SELECT date_val, time_val, ts_val FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertNil(result.rows[0][0])
        XCTAssertNil(result.rows[0][1])
        XCTAssertNil(result.rows[0][2])
    }

    // MARK: - Date/Time Extraction

    func testExtractYear() async throws {
        let result = try await query("SELECT EXTRACT(YEAR FROM '2024-03-15'::DATE)::INTEGER AS yr")
        XCTAssertEqual(result.rows[0][0], "2024")
    }

    func testExtractMonth() async throws {
        let result = try await query("SELECT EXTRACT(MONTH FROM '2024-03-15'::DATE)::INTEGER AS mon")
        XCTAssertEqual(result.rows[0][0], "3")
    }

    func testExtractDay() async throws {
        let result = try await query("SELECT EXTRACT(DAY FROM '2024-03-15'::DATE)::INTEGER AS d")
        XCTAssertEqual(result.rows[0][0], "15")
    }

    func testExtractEpochFromTimestamp() async throws {
        let result = try await query("""
            SELECT EXTRACT(EPOCH FROM '1970-01-01 00:00:00'::TIMESTAMP)::INTEGER AS epoch_val
        """)
        XCTAssertEqual(result.rows[0][0], "0")
    }

    // MARK: - Age and Difference

    func testAgeBetweenDates() async throws {
        let result = try await query("SELECT age('2024-03-15'::DATE, '2023-01-01'::DATE) AS diff")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testDateDifference() async throws {
        let result = try await query("""
            SELECT ('2024-03-15'::DATE - '2024-03-01'::DATE) AS day_diff
        """)
        XCTAssertEqual(result.rows[0][0], "14")
    }
}
