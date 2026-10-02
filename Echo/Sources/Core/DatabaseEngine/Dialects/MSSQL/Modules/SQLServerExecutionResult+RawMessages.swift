import Foundation
import SQLServerKit

extension SQLServerExecutionResult {
    func echoServerMessages() -> [ServerMessage] {
        let infoAndErrorMessages = messages.map(\.echoServerMessage)

        let completionMessages = done.map { done in
            let status = String(format: "0x%04X", done.status)
            let curCmd = String(format: "0x%04X", done.curCmd)
            let text = "DONE kind=\(done.kind.rawValue) status=\(status) curCmd=\(curCmd) rowCount=\(done.rowCount)"
            return ServerMessage(
                kind: .info,
                number: 0,
                message: text,
                state: 0,
                severity: 0,
                category: "Driver Response",
                metadata: [
                    "source": "echo-sqlserver",
                    "token": "DONE",
                    "kind": done.kind.rawValue,
                    "status": status,
                    "curCmd": curCmd,
                    "rowCount": "\(done.rowCount)"
                ]
            )
        }

        return infoAndErrorMessages + completionMessages
    }
}
