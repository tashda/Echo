import Foundation
import NIOCore
import PostgresKit
import PostgresWire

struct CellFormatterContext: Sendable {
    nonisolated private static let postgresEpoch: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2000
        components.month = 1
        components.day = 1
        return components.date!
    }()
    
    nonisolated private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    
    nonisolated private static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }
    
    nonisolated func stringValue(for cell: PostgresCell) -> String? {
        guard let buffer = cell.bytes else { return nil }
        
        if cell.format == .text {
            let readableBytes = buffer.readableBytes
            guard readableBytes > 0 else { return "" }
            let raw = buffer.getString(at: buffer.readerIndex, length: readableBytes) ?? ""
            if cell.dataType == .bool {
                if raw == "t" { return "true" }
                if raw == "f" { return "false" }
            }
            return raw
        }
        
        switch cell.dataType {
        case .bool:
            if let value = try? cell.decode(Bool.self) {
                return value ? "true" : "false"
            }
        case .int2:
            return integerString(from: cell, as: Int16.self)
        case .int4:
            return integerString(from: cell, as: Int32.self)
        case .int8:
            return integerString(from: cell, as: Int64.self)
        case .float4:
            if let value = try? cell.decode(Float.self) {
                return String(value)
            }
        case .float8:
            if let value = try? cell.decode(Double.self) {
                return String(value)
            }
        case .numeric, .money:
            if let decimalValue = try? cell.decode(Decimal.self, context: .default) {
                return NSDecimalNumber(decimal: decimalValue).stringValue
            }
        case .json, .jsonb:
            if let string = try? cell.decode(String.self, context: .default) {
                return string
            }
        case .bytea:
            if var mutableBuffer = cell.bytes {
                return hexString(from: &mutableBuffer)
            }
        case .timestamp:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self) {
                return formatTimestamp(microseconds: microseconds)
            }
        case .timestamptz:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self) {
                return formatTimestampWithTimeZone(microseconds: microseconds)
            }
        case .date:
            if var mutableBuffer = cell.bytes,
               let days: Int32 = mutableBuffer.readInteger(as: Int32.self) {
                return formatDate(days: Int(days))
            }
        case .time:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self) {
                return formatTime(microseconds: microseconds)
            }
        case .timetz:
            if var mutableBuffer = cell.bytes,
               let microseconds: Int64 = mutableBuffer.readInteger(as: Int64.self),
               let tzOffset: Int32 = mutableBuffer.readInteger(as: Int32.self) {
                return formatTimeWithTimeZone(microseconds: microseconds, offsetMinutesWest: Int(tzOffset))
            }
        default:
            if let string = try? cell.decode(String.self, context: .default) {
                return string
            }
        }
        
        if var mutableBuffer = cell.bytes {
            return hexString(from: &mutableBuffer)
        }
        return nil
    }
    
    private nonisolated func integerString<Integer>(from cell: PostgresCell, as type: Integer.Type) -> String?
    where Integer: FixedWidthInteger & PostgresDecodable {
        guard let value = try? cell.decode(type, context: .default) else { return nil }
        return String(value)
    }
    
    private nonisolated func hexString(from buffer: inout ByteBuffer) -> String {
        let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    
    private nonisolated func formatTimestamp(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let date = Date(timeInterval: TimeInterval(seconds), since: Self.postgresEpoch)
        let calendar = Self.utcCalendar
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day,
            let hour = components.hour,
            let minute = components.minute,
            let second = components.second
        else {
            return ""
        }
        let fractional = formatFractionalMicroseconds(microsRemainder)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d%@", year, month, day, hour, minute, second, fractional)
    }
    
    private nonisolated func formatTimestampWithTimeZone(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let date = Date(timeInterval: TimeInterval(seconds), since: Self.postgresEpoch)
        let calendar = Self.localCalendar
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day,
            let hour = components.hour,
            let minute = components.minute,
            let second = components.second
        else {
            return ""
        }
        let fractional = formatFractionalMicroseconds(microsRemainder)
        let timeZone = components.timeZone ?? TimeZone.current
        let offsetSeconds = timeZone.secondsFromGMT(for: date)
        let offsetSign = offsetSeconds >= 0 ? "+" : "-"
        let offset = abs(offsetSeconds)
        let offsetHours = offset / 3600
        let offsetMinutes = (offset % 3600) / 60
        return String(
            format: "%04d-%02d-%02d %02d:%02d:%02d%@%@%02d:%02d",
            year,
            month,
            day,
            hour,
            minute,
            second,
            fractional,
            offsetSign,
            offsetHours,
            offsetMinutes
        )
    }
    
    private nonisolated func formatDate(days: Int) -> String {
        if let date = Self.utcCalendar.date(byAdding: .day, value: days, to: Self.postgresEpoch) {
            let components = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
            if let year = components.year, let month = components.month, let day = components.day {
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
        }
        return ""
    }
    
    private nonisolated func formatTime(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let normalizedSeconds = ((seconds % 86_400) + 86_400) % 86_400
        let hour = normalizedSeconds / 3_600
        let minute = (normalizedSeconds % 3_600) / 60
        let second = normalizedSeconds % 60
        let fractional = formatFractionalMicroseconds(microsRemainder)
        return String(format: "%02d:%02d:%02d%@", hour, minute, second, fractional)
    }
    
    private nonisolated func formatTimeWithTimeZone(microseconds: Int64, offsetMinutesWest: Int) -> String {
        let timeString = formatTime(microseconds: microseconds)
        let minutesEast = -offsetMinutesWest
        let sign = minutesEast >= 0 ? "+" : "-"
        let absoluteMinutes = abs(minutesEast)
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        return String(format: "%@%@%02d:%02d", timeString, sign, hours, minutes)
    }
    
    nonisolated private static func splitMicroseconds(_ value: Int64) -> (seconds: Int64, remainder: Int64) {
        var seconds = value / 1_000_000
        var remainder = value % 1_000_000
        if remainder < 0 {
            remainder += 1_000_000
            seconds -= 1
        }
        return (seconds, remainder)
    }
    
    private nonisolated func formatFractionalMicroseconds(_ value: Int64) -> String {
        guard value != 0 else { return "" }
        var fractional = String(format: "%06lld", value)
        while fractional.last == "0" {
            fractional.removeLast()
        }
        return "." + fractional
    }
}
