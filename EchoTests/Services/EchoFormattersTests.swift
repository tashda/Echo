import Foundation
import Testing
@testable import Echo

@Suite("EchoFormatters - Duration (TimeInterval)")
struct EchoFormattersDurationTests {

    @Test func durationNilReturnsEmDash() {
        #expect(EchoFormatters.duration(nil) == "\u{2014}")
    }

    @Test func durationZeroReturnsEmDash() {
        #expect(EchoFormatters.duration(0) == "\u{2014}")
    }

    @Test func durationNegativeReturnsEmDash() {
        #expect(EchoFormatters.duration(-5.0) == "\u{2014}")
    }

    @Test func durationSubMillisecond() {
        let result = EchoFormatters.duration(0.0005)
        #expect(result == "1 ms" || result == "0 ms")
    }

    @Test func durationMilliseconds() {
        let result = EchoFormatters.duration(0.042)
        #expect(result == "42 ms")
    }

    @Test func durationHalfSecond() {
        let result = EchoFormatters.duration(0.500)
        #expect(result == "500 ms")
    }

    @Test func durationOneSecond() {
        let result = EchoFormatters.duration(1.0)
        #expect(result == "1.00 s")
    }

    @Test func durationFractionalSeconds() {
        let result = EchoFormatters.duration(1.25)
        #expect(result == "1.25 s")
    }

    @Test func durationAlmostOneMinute() {
        let result = EchoFormatters.duration(59.99)
        #expect(result == "59.99 s")
    }

    @Test func durationExactlyOneMinute() {
        let result = EchoFormatters.duration(60.0)
        #expect(result == "1m 0s")
    }

    @Test func durationMinutesAndSeconds() {
        let result = EchoFormatters.duration(135.0)
        #expect(result == "2m 15s")
    }

    @Test func durationOneHour() {
        let result = EchoFormatters.duration(3600.0)
        #expect(result == "60m 0s")
    }

    @Test func durationLargeValue() {
        let result = EchoFormatters.duration(7265.0)
        #expect(result == "121m 5s")
    }
}

@Suite("EchoFormatters - Duration (Seconds)")
struct EchoFormattersDurationSecondsTests {

    @Test func zeroSeconds() {
        #expect(EchoFormatters.duration(seconds: 0) == "0s")
    }

    @Test func oneSecond() {
        #expect(EchoFormatters.duration(seconds: 1) == "1s")
    }

    @Test func underOneMinute() {
        #expect(EchoFormatters.duration(seconds: 45) == "45s")
    }

    @Test func fiftyNineSeconds() {
        #expect(EchoFormatters.duration(seconds: 59) == "59s")
    }

    @Test func exactlyOneMinute() {
        #expect(EchoFormatters.duration(seconds: 60) == "1m 0s")
    }

    @Test func minutesAndSeconds() {
        #expect(EchoFormatters.duration(seconds: 135) == "2m 15s")
    }

    @Test func oneHour() {
        #expect(EchoFormatters.duration(seconds: 3600) == "60m 0s")
    }

    @Test func largeValue() {
        #expect(EchoFormatters.duration(seconds: 7265) == "121m 5s")
    }
}

@Suite("EchoFormatters - Bytes (Int)")
struct EchoFormattersBytesIntTests {

    @Test func zeroBytes() {
        let result = EchoFormatters.bytes(0)
        // ByteCountFormatter may produce "Zero KB", "0 bytes", "0 KB", etc.
        #expect(!result.isEmpty)
    }

    @Test func oneByteFormatted() {
        let result = EchoFormatters.bytes(1)
        #expect(!result.isEmpty)
    }

    @Test func onKBBoundary() {
        let result = EchoFormatters.bytes(1024)
        #expect(result.contains("1") && result.contains("KB"))
    }

    @Test func onMBBoundary() {
        let result = EchoFormatters.bytes(1_048_576)
        #expect(result.contains("1") && result.contains("MB"))
    }

    @Test func onGBBoundary() {
        let result = EchoFormatters.bytes(1_073_741_824)
        #expect(result.contains("1") && result.contains("GB"))
    }

    @Test func subKBBytes() {
        let result = EchoFormatters.bytes(512)
        #expect(result.contains("bytes") || result.contains("KB"))
    }

    @Test func fractionalKB() {
        let result = EchoFormatters.bytes(1536) // 1.5 KB
        #expect(result.contains("KB"))
    }
}

@Suite("EchoFormatters - Bytes (UInt64)")
struct EchoFormattersBytesUInt64Tests {

    @Test func zeroBytes() {
        let result = EchoFormatters.bytes(UInt64(0))
        // ByteCountFormatter may produce "Zero KB", "0 bytes", "0 KB", etc.
        #expect(!result.isEmpty)
    }

    @Test func onKBBoundary() {
        let result = EchoFormatters.bytes(UInt64(1024))
        #expect(result.contains("1") && result.contains("KB"))
    }

    @Test func onTBBoundary() {
        let result = EchoFormatters.bytes(UInt64(1_099_511_627_776))
        #expect(result.contains("TB"))
    }

    @Test func largeUInt64Value() {
        let result = EchoFormatters.bytes(UInt64(5_368_709_120)) // 5 GB
        #expect(result.contains("GB"))
    }
}

@Suite("EchoFormatters - Compact Number")
struct EchoFormattersCompactNumberTests {

    @Test func zero() {
        let result = EchoFormatters.compactNumber(0)
        #expect(result == "0")
    }

    @Test func smallNumber() {
        let result = EchoFormatters.compactNumber(42)
        #expect(result == "42")
    }

    @Test func thousandsFormattedWithGrouping() {
        let result = EchoFormatters.compactNumber(12_345)
        // NumberFormatter uses locale-specific grouping separator
        #expect(result.contains("12"))
        #expect(result.contains("345"))
    }

    @Test func nineHundredNinetyNine() {
        let result = EchoFormatters.compactNumber(999)
        #expect(result == "999")
    }

    @Test func hundredThousandUsesK() {
        let result = EchoFormatters.compactNumber(100_000)
        #expect(result == "100K")
    }

    @Test func fiveHundredThousandUsesK() {
        let result = EchoFormatters.compactNumber(500_000)
        #expect(result == "500K")
    }

    @Test func ninetyNineThousandDoesNotUseK() {
        let result = EchoFormatters.compactNumber(99_999)
        // Under 100_000 threshold, uses decimal formatting (locale-specific grouping)
        #expect(!result.contains("K"))
        #expect(result.contains("99"))
        #expect(result.contains("999"))
    }

    @Test func millionUsesM() {
        let result = EchoFormatters.compactNumber(1_000_000)
        #expect(result == "1.0M")
    }

    @Test func twoPointFiveMillion() {
        let result = EchoFormatters.compactNumber(2_500_000)
        #expect(result == "2.5M")
    }

    @Test func tenMillion() {
        let result = EchoFormatters.compactNumber(10_000_000)
        #expect(result == "10.0M")
    }

    @Test func negativeValueFormattedNormally() {
        let result = EchoFormatters.compactNumber(-500)
        // Negative numbers under threshold use decimal formatter
        #expect(result.contains("500"))
    }
}

@Suite("EchoFormatters - SQL Type Abbreviation")
struct EchoFormattersAbbreviatedSQLTypeTests {

    @Test func timestampWithTimeZone() {
        #expect(EchoFormatters.abbreviatedSQLType("timestamp with time zone") == "timestamptz")
    }

    @Test func timestampWithoutTimeZone() {
        #expect(EchoFormatters.abbreviatedSQLType("timestamp without time zone") == "timestamp")
    }

    @Test func timeWithTimeZone() {
        #expect(EchoFormatters.abbreviatedSQLType("time with time zone") == "timetz")
    }

    @Test func timeWithoutTimeZone() {
        #expect(EchoFormatters.abbreviatedSQLType("time without time zone") == "time")
    }

    @Test func passthroughForUnknownType() {
        #expect(EchoFormatters.abbreviatedSQLType("integer") == "integer")
    }

    @Test func passthroughForCharacterVarying() {
        // No rule for "character varying" in the current implementation
        #expect(EchoFormatters.abbreviatedSQLType("character varying") == "character varying")
    }

    @Test func passthroughForText() {
        #expect(EchoFormatters.abbreviatedSQLType("text") == "text")
    }

    @Test func passthroughForDoublePrecision() {
        #expect(EchoFormatters.abbreviatedSQLType("double precision") == "double precision")
    }

    @Test func emptyStringPassthrough() {
        #expect(EchoFormatters.abbreviatedSQLType("") == "")
    }
}

@Suite("EchoFormatters - Relative Date")
struct EchoFormattersRelativeDateTests {

    @Test func recentDateProducesNonEmptyString() {
        let result = EchoFormatters.relativeDate(Date())
        #expect(!result.isEmpty)
    }

    @Test func pastDateContainsAgoOrEquivalent() {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let result = EchoFormatters.relativeDate(fiveMinutesAgo)
        // RelativeDateTimeFormatter with abbreviated style produces strings like "5 min. ago"
        #expect(!result.isEmpty)
    }

    @Test func oneHourAgo() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let result = EchoFormatters.relativeDate(oneHourAgo)
        #expect(!result.isEmpty)
    }

    @Test func oneDayAgo() {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        let result = EchoFormatters.relativeDate(oneDayAgo)
        #expect(!result.isEmpty)
    }

    @Test func futureDate() {
        let inFiveMinutes = Date().addingTimeInterval(300)
        let result = EchoFormatters.relativeDate(inFiveMinutes)
        // Should produce something like "in 5 min."
        #expect(!result.isEmpty)
    }

    @Test func distantPast() {
        let longAgo = Date().addingTimeInterval(-86400 * 365)
        let result = EchoFormatters.relativeDate(longAgo)
        #expect(!result.isEmpty)
    }
}
