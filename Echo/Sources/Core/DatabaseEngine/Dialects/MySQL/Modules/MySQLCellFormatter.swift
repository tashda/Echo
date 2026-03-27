import Foundation
import MySQLWire
import NIOCore

internal struct MySQLCellFormatter {
    private let dateFormatter: DateFormatter
    private let dateTimeFormatter: ISO8601DateFormatter
    private let timeFormatter: DateFormatter

    init() {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = dateFormatter

        let dateTimeFormatter = ISO8601DateFormatter()
        dateTimeFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dateTimeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateTimeFormatter = dateTimeFormatter

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        timeFormatter.dateFormat = "HH:mm:ss"
        self.timeFormatter = timeFormatter
    }

    func stringValue(for data: MySQLData) -> String? {
        guard data.buffer != nil else { return nil }

        switch data.type {
        case .null:
            return nil
        case .tiny, .short, .long, .longlong, .int24, .bit, .year:
            if let int = data.int64 { return String(int) }
            if let uint = data.uint64 { return String(uint) }
        case .float:
            if let value = data.float { return formatFloatingPoint(Double(value)) }
        case .double:
            if let value = data.double { return formatFloatingPoint(value) }
        case .decimal, .newdecimal:
            return textString(from: data)
        case .timestamp, .timestamp2, .datetime, .datetime2:
            if let date = data.date { return dateTimeFormatter.string(from: date) }
        case .date, .newdate:
            if let date = data.date { return dateFormatter.string(from: date) }
        case .time, .time2:
            if let time = data.time { return string(from: time) }
        case .json:
            return textString(from: data)
        case .blob, .longBlob, .mediumBlob, .tinyBlob, .geometry:
            if let text = textString(from: data) {
                return text
            }
            return data.buffer.flatMap { hexString(from: $0) }
        case .varchar, .varString, .string, .enum, .set:
            return textString(from: data)
        default:
            break
        }

        if let text = textString(from: data) {
            return text
        }

        if let buffer = data.buffer {
            return hexString(from: buffer)
        }

        return nil
    }

    private func textString(from data: MySQLData) -> String? {
        if let string = data.string {
            return string
        }
        guard var buffer = data.buffer else {
            return nil
        }
        let length = buffer.readableBytes
        if length == 0 {
            return ""
        }
        return buffer.readString(length: length)
    }

    private func string(from time: MySQLTime) -> String? {
        guard let date = time.date else {
            guard
                let hour = time.hour,
                let minute = time.minute,
                let second = time.second
            else { return nil }
            let fractional = time.microsecond ?? 0
            let base = String(format: "%02d:%02d:%02d", hour, minute, second)
            if fractional == 0 { return base }
            var fractionalString = String(format: "%06d", fractional)
            while fractionalString.last == "0" { fractionalString.removeLast() }
            return base + "." + fractionalString
        }
        return timeFormatter.string(from: date)
    }

    private func formatFloatingPoint(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value > 0 ? "Infinity" : "-Infinity" }
        let absValue = abs(value)
        if (absValue >= 1e-4 && absValue < 1e6) || value == 0 {
            return String(format: "%.15g", value)
        }
        return String(value)
    }

    private func hexString(from buffer: ByteBuffer) -> String {
        guard let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) else { return "0x" }
        return bytes.reduce(into: "0x") { partial, byte in
            partial.append(String(format: "%02X", byte))
        }
    }
}
