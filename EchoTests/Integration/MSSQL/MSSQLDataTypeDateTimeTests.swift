import XCTest
@testable import Echo

/// Tests SQL Server date/time data type round-trips through Echo's DatabaseSession layer.
final class MSSQLDataTypeDateTimeTests: MSSQLDockerTestCase {

    // MARK: - DATE

    func testDateType() async throws {
        let result = try await query("SELECT CAST('2024-06-15' AS DATE) AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(
            result.rows[0][0]?.contains("2024") ?? false,
            "Date should contain year 2024"
        )
    }

    func testDateMinMax() async throws {
        let result = try await query("""
            SELECT CAST('0001-01-01' AS DATE) AS min_date,
                   CAST('9999-12-31' AS DATE) AS max_date
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    // MARK: - TIME

    func testTimeType() async throws {
        let result = try await query("SELECT CAST('14:30:45' AS TIME) AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = result.rows[0][0] ?? ""
        XCTAssertTrue(value.contains("14:30:45"), "Time should contain 14:30:45, got: \(value)")
    }

    func testTimeWithFractionalSeconds() async throws {
        let result = try await query("SELECT CAST('14:30:45.1234567' AS TIME(7)) AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = result.rows[0][0] ?? ""
        XCTAssertTrue(value.contains("14:30:45"), "Time should contain base time")
    }

    func testTimeWithLowPrecision() async throws {
        let result = try await query("SELECT CAST('08:15:30.12' AS TIME(2)) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - DATETIME

    func testDatetimeType() async throws {
        let result = try await query("SELECT CAST('2024-06-15 14:30:45.123' AS DATETIME) AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = result.rows[0][0] ?? ""
        XCTAssertTrue(value.contains("2024"), "Datetime should contain year")
        XCTAssertTrue(value.contains("14:30"), "Datetime should contain time")
    }

    func testDatetimeRounding() async throws {
        // DATETIME rounds to .000, .003, or .007
        let result = try await query("SELECT CAST('2024-01-01 00:00:00.001' AS DATETIME) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - DATETIME2

    func testDatetime2Type() async throws {
        let result = try await query("SELECT CAST('2024-06-15 14:30:45.1234567' AS DATETIME2) AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = result.rows[0][0] ?? ""
        XCTAssertTrue(value.contains("2024"), "Datetime2 should contain year")
    }

    func testDatetime2WithPrecision() async throws {
        let result = try await query("""
            SELECT CAST('2024-06-15 14:30:45.12' AS DATETIME2(2)) AS prec2,
                   CAST('2024-06-15 14:30:45.1234' AS DATETIME2(4)) AS prec4,
                   CAST('2024-06-15 14:30:45.1234567' AS DATETIME2(7)) AS prec7
        """)
        for i in 0..<3 {
            XCTAssertNotNil(result.rows[0][i], "Precision variant \(i) should not be null")
        }
    }

    func testDatetime2MinMax() async throws {
        let result = try await query("""
            SELECT CAST('0001-01-01 00:00:00.0000000' AS DATETIME2(7)) AS min_val,
                   CAST('9999-12-31 23:59:59.9999999' AS DATETIME2(7)) AS max_val
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    // MARK: - DATETIMEOFFSET

    func testDatetimeoffsetType() async throws {
        let result = try await query(
            "SELECT CAST('2024-06-15 14:30:45.1234567 +05:30' AS DATETIMEOFFSET) AS val"
        )
        XCTAssertNotNil(result.rows[0][0])
        let value = result.rows[0][0] ?? ""
        XCTAssertTrue(value.contains("2024"), "Should contain year")
    }

    func testDatetimeoffsetWithTimezone() async throws {
        let result = try await query("""
            SELECT CAST('2024-06-15 14:30:00 +00:00' AS DATETIMEOFFSET) AS utc,
                   CAST('2024-06-15 14:30:00 -05:00' AS DATETIMEOFFSET) AS eastern,
                   CAST('2024-06-15 14:30:00 +09:00' AS DATETIMEOFFSET) AS tokyo
        """)
        for i in 0..<3 {
            XCTAssertNotNil(result.rows[0][i], "Timezone variant \(i) should not be null")
        }
    }

    func testDatetimeoffsetConversion() async throws {
        let result = try await query("""
            SELECT
                CAST('2024-06-15 14:30:00 +05:30' AS DATETIMEOFFSET) AS original,
                SWITCHOFFSET(CAST('2024-06-15 14:30:00 +05:30' AS DATETIMEOFFSET), '+00:00') AS utc_converted
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    // MARK: - SMALLDATETIME

    func testSmalldatetimeType() async throws {
        let result = try await query("SELECT CAST('2024-06-15 14:30:00' AS SMALLDATETIME) AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = result.rows[0][0] ?? ""
        XCTAssertTrue(value.contains("2024"), "Smalldatetime should contain year")
    }

    func testSmalldatetimeRounding() async throws {
        // SMALLDATETIME rounds to the nearest minute
        let result = try await query("""
            SELECT CAST('2024-01-01 12:30:29' AS SMALLDATETIME) AS rounded_down,
                   CAST('2024-01-01 12:30:30' AS SMALLDATETIME) AS rounded_up
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    // MARK: - NULL Handling

    func testNullDateValues() async throws {
        let result = try await query("""
            SELECT CAST(NULL AS DATE) AS null_date,
                   CAST(NULL AS TIME) AS null_time,
                   CAST(NULL AS DATETIME) AS null_datetime,
                   CAST(NULL AS DATETIME2) AS null_datetime2,
                   CAST(NULL AS DATETIMEOFFSET) AS null_dto,
                   CAST(NULL AS SMALLDATETIME) AS null_smalldt
        """)
        for i in 0..<6 {
            XCTAssertNil(result.rows[0][i], "Column \(i) should be NULL")
        }
    }

    func testNullDateInTable() async throws {
        try await withTempTable(
            columns: "id INT PRIMARY KEY, dt DATE NULL, dt2 DATETIME2 NULL, dto DATETIMEOFFSET NULL"
        ) { tableName in
            try await execute("INSERT INTO [\(tableName)] (id) VALUES (1)")

            let result = try await query("SELECT * FROM [\(tableName)]")
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertNil(result.rows[0][1], "dt should be NULL")
            XCTAssertNil(result.rows[0][2], "dt2 should be NULL")
            XCTAssertNil(result.rows[0][3], "dto should be NULL")
        }
    }

    // MARK: - Table Round-Trip

    func testDateTimeRoundTripThroughTable() async throws {
        try await withTempTable(
            columns: """
                id INT PRIMARY KEY,
                date_col DATE,
                time_col TIME(7),
                dt_col DATETIME,
                dt2_col DATETIME2(7),
                dto_col DATETIMEOFFSET(7),
                sdt_col SMALLDATETIME
            """
        ) { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] VALUES (
                    1,
                    '2024-06-15',
                    '14:30:45.1234567',
                    '2024-06-15 14:30:45.123',
                    '2024-06-15 14:30:45.1234567',
                    '2024-06-15 14:30:45.1234567 +05:30',
                    '2024-06-15 14:30:00'
                )
            """)

            let result = try await query("SELECT * FROM [\(tableName)]")
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertEqual(result.columns.count, 7)

            // Every column should have a non-null value
            for (i, col) in result.columns.enumerated() {
                XCTAssertNotNil(result.rows[0][i], "Column \(col.name) should have a value")
            }
        }
    }

    func testMultipleDateRowsRoundTrip() async throws {
        try await withTempTable(
            columns: "id INT PRIMARY KEY, created_at DATETIME2, expires_at DATETIME2 NULL"
        ) { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] VALUES
                    (1, '2024-01-01 00:00:00', '2024-12-31 23:59:59'),
                    (2, '2024-06-15 12:30:00', NULL),
                    (3, '2024-03-20 08:15:30', '2025-03-20 08:15:30')
            """)

            let result = try await query("SELECT * FROM [\(tableName)] ORDER BY id")
            IntegrationTestHelpers.assertRowCount(result, expected: 3)

            // Row 2 should have NULL expires_at
            XCTAssertNotNil(result.rows[1][1], "created_at should not be null")
            XCTAssertNil(result.rows[1][2], "expires_at should be null for row 2")
        }
    }

    // MARK: - Date Arithmetic

    func testDateAdd() async throws {
        let result = try await query("""
            SELECT
                DATEADD(day, 7, CAST('2024-06-15' AS DATE)) AS plus_7_days,
                DATEADD(month, 3, CAST('2024-06-15' AS DATE)) AS plus_3_months,
                DATEADD(year, 1, CAST('2024-06-15' AS DATE)) AS plus_1_year,
                DATEADD(hour, 6, CAST('2024-06-15 14:00:00' AS DATETIME2)) AS plus_6_hours,
                DATEADD(minute, 30, CAST('2024-06-15 14:00:00' AS DATETIME2)) AS plus_30_min
        """)

        for i in 0..<5 {
            XCTAssertNotNil(result.rows[0][i], "DATEADD result \(i) should not be null")
        }
    }

    func testDateDiff() async throws {
        let result = try await query("""
            SELECT
                DATEDIFF(day, '2024-01-01', '2024-06-15') AS days_diff,
                DATEDIFF(month, '2024-01-01', '2024-06-15') AS months_diff,
                DATEDIFF(year, '2020-01-01', '2024-06-15') AS years_diff,
                DATEDIFF(hour, '2024-06-15 08:00:00', '2024-06-15 14:30:00') AS hours_diff,
                DATEDIFF(second, '2024-06-15 14:00:00', '2024-06-15 14:05:30') AS seconds_diff
        """)

        XCTAssertEqual(result.rows[0][0], "166", "Days from Jan 1 to Jun 15")
        XCTAssertEqual(result.rows[0][1], "5", "Months from Jan to Jun")
        XCTAssertEqual(result.rows[0][2], "4", "Years from 2020 to 2024")
    }

    // MARK: - Date Functions

    func testGetDate() async throws {
        let result = try await query("SELECT GETDATE() AS now, GETUTCDATE() AS utc_now")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    func testSysDateTime() async throws {
        let result = try await query("""
            SELECT SYSDATETIME() AS sys_now,
                   SYSUTCDATETIME() AS sys_utc,
                   SYSDATETIMEOFFSET() AS sys_offset
        """)
        for i in 0..<3 {
            XCTAssertNotNil(result.rows[0][i], "System datetime function \(i) should return a value")
        }
    }

    func testDatePartExtraction() async throws {
        let result = try await query("""
            SELECT
                YEAR(CAST('2024-06-15' AS DATE)) AS yr,
                MONTH(CAST('2024-06-15' AS DATE)) AS mo,
                DAY(CAST('2024-06-15' AS DATE)) AS dy,
                DATEPART(weekday, CAST('2024-06-15' AS DATE)) AS weekday,
                DATENAME(month, CAST('2024-06-15' AS DATE)) AS month_name
        """)
        XCTAssertEqual(result.rows[0][0], "2024")
        XCTAssertEqual(result.rows[0][1], "6")
        XCTAssertEqual(result.rows[0][2], "15")
        XCTAssertNotNil(result.rows[0][3])
        XCTAssertEqual(result.rows[0][4], "June")
    }
}
