import Foundation
import NIOCore

extension CellFormatterContext {
    nonisolated func formatTimestamp(microseconds: Int64) -> String {
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

    nonisolated func formatTimestampWithTimeZone(microseconds: Int64) -> String {
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

    nonisolated func formatDate(days: Int) -> String {
        if let date = Self.utcCalendar.date(byAdding: .day, value: days, to: Self.postgresEpoch) {
            let components = Self.utcCalendar.dateComponents([.year, .month, .day], from: date)
            if let year = components.year, let month = components.month, let day = components.day {
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
        }
        return ""
    }

    nonisolated func formatTime(microseconds: Int64) -> String {
        let (seconds, microsRemainder) = Self.splitMicroseconds(microseconds)
        let normalizedSeconds = ((seconds % 86_400) + 86_400) % 86_400
        let hour = normalizedSeconds / 3_600
        let minute = (normalizedSeconds % 3_600) / 60
        let second = normalizedSeconds % 60
        let fractional = formatFractionalMicroseconds(microsRemainder)
        return String(format: "%02d:%02d:%02d%@", hour, minute, second, fractional)
    }

    nonisolated func formatTimeWithTimeZone(microseconds: Int64, offsetMinutesWest: Int) -> String {
        let timeString = formatTime(microseconds: microseconds)
        let minutesEast = -offsetMinutesWest
        let sign = minutesEast >= 0 ? "+" : "-"
        let absoluteMinutes = abs(minutesEast)
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        return String(format: "%@%@%02d:%02d", timeString, sign, hours, minutes)
    }

    nonisolated func formatFractionalMicroseconds(_ value: Int64) -> String {
        guard value != 0 else { return "" }
        var fractional = String(format: "%06lld", value)
        while fractional.last == "0" {
            fractional.removeLast()
        }
        return "." + fractional
    }
}
