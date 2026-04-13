import Foundation
import SQLServerKit

extension SQLServerExecutionResult {
    func echoServerMessages() -> [ServerMessage] {
        let infoAndErrorMessages = messages.map { message in
            ServerMessage(
                kind: message.kind == .error ? .error : .info,
                number: message.number,
                message: message.message,
                state: message.state,
                severity: message.severity,
                serverName: message.serverName.isEmpty ? nil : message.serverName,
                procedureName: message.procedureName.isEmpty ? nil : message.procedureName,
                lineNumber: message.lineNumber,
                category: "Server Response",
                metadata: [
                    "source": "sqlserver-nio",
                    "token": message.kind == .error ? "ERROR" : "INFO"
                ]
            )
        }

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
                    "source": "sqlserver-nio",
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
