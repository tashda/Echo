import XCTest
@testable import Echo

final class ResultGridValueClassifierTests: XCTestCase {

    // MARK: - Null Handling

    func testNilValueReturnsNull() {
        let column = TestFixtures.columnInfo(dataType: "integer")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: nil), .null)
    }

    func testNilColumnReturnsText() {
        XCTAssertEqual(ResultGridValueClassifier.kind(for: nil, value: "hello"), .text)
    }

    // MARK: - Numeric Types

    func testIntegerClassifiedAsNumeric() {
        let column = TestFixtures.columnInfo(dataType: "integer")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "42"), .numeric)
    }

    func testBigintClassifiedAsNumeric() {
        let column = TestFixtures.columnInfo(dataType: "bigint")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "123456789"), .numeric)
    }

    func testDecimalClassifiedAsNumeric() {
        let column = TestFixtures.columnInfo(dataType: "decimal(10,2)")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "99.99"), .numeric)
    }

    func testFloat8ClassifiedAsNumeric() {
        let column = TestFixtures.columnInfo(dataType: "float8")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "3.14"), .numeric)
    }

    // MARK: - Boolean Types

    func testBooleanClassifiedAsBoolean() {
        let column = TestFixtures.columnInfo(dataType: "boolean")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "true"), .boolean)
    }

    func testBitClassifiedAsBoolean() {
        let column = TestFixtures.columnInfo(dataType: "bit")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "1"), .boolean)
    }

    func testBitVaryingClassifiedAsBinary() {
        let column = TestFixtures.columnInfo(dataType: "bit varying")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "1010"), .binary)
    }

    // MARK: - Temporal Types

    func testTimestampClassifiedAsTemporal() {
        let column = TestFixtures.columnInfo(dataType: "timestamp")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "2024-01-01"), .temporal)
    }

    func testDateClassifiedAsTemporal() {
        let column = TestFixtures.columnInfo(dataType: "date")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "2024-01-01"), .temporal)
    }

    func testTimestamptzClassifiedAsTemporal() {
        let column = TestFixtures.columnInfo(dataType: "timestamptz")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "2024-01-01T00:00:00Z"), .temporal)
    }

    // MARK: - JSON Types

    func testJsonClassifiedAsJson() {
        let column = TestFixtures.columnInfo(dataType: "json")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "{}"), .json)
    }

    func testJsonbClassifiedAsJson() {
        let column = TestFixtures.columnInfo(dataType: "jsonb")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "[]"), .json)
    }

    // MARK: - Identifier Types

    func testUuidClassifiedAsIdentifier() {
        let column = TestFixtures.columnInfo(dataType: "uuid")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "550e8400-e29b-41d4-a716-446655440000"), .identifier)
    }

    func testUniqueidentifierClassifiedAsIdentifier() {
        let column = TestFixtures.columnInfo(dataType: "uniqueidentifier")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "ABC"), .identifier)
    }

    // MARK: - Binary Types

    func testByteaClassifiedAsBinary() {
        let column = TestFixtures.columnInfo(dataType: "bytea")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "\\x00"), .binary)
    }

    // MARK: - Text Fallback

    func testVarcharClassifiedAsText() {
        let column = TestFixtures.columnInfo(dataType: "varchar(255)")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "hello"), .text)
    }

    func testTextClassifiedAsText() {
        let column = TestFixtures.columnInfo(dataType: "text")
        XCTAssertEqual(ResultGridValueClassifier.kind(for: column, value: "hello"), .text)
    }

    // MARK: - Data Type String Classification

    func testKindForDataType() {
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: "integer", value: "1"), .numeric)
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: "boolean", value: "true"), .boolean)
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: nil, value: "hello"), .text)
        XCTAssertEqual(ResultGridValueClassifier.kind(forDataType: "json", value: nil), .null)
    }
}
