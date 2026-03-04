import Foundation
import NIOCore
import NIOFoundationCompat
import PostgresKit
import PostgresWire

extension ResultCellPayload {
    nonisolated init(cell: PostgresCell) {
        let formatRaw = UInt8(clamping: cell.format.rawValue)
        let format = ResultCellPayload.Format(rawValue: formatRaw) ?? .text

        let data: Data?
        if var buffer = cell.bytes {
            let readable = buffer.readableBytes
            if readable > 0 {
                if let extracted = buffer.readData(length: readable) {
                    data = extracted
                } else if let bytes = buffer.readBytes(length: readable) {
                    data = Data(bytes)
                } else {
                    data = Data()
                }
            } else {
                data = Data()
            }
        } else {
            data = nil
        }

        self.init(dataTypeOID: cell.dataType.rawValue, format: format, bytes: data)
    }
}
