import SwiftUI

/// Interactive pages that call the real packages: EchoSense, connections, drivers.
@MainActor
enum TestPages {
    static let all: [LabPage] = [
        LabPage(
            id: "test.echosense",
            section: .test,
            group: "EchoSense",
            title: "Completions",
            symbol: "text.badge.star",
            summary: "Type SQL and move the caret to see exactly what EchoSense offers, in what order, and why."
        ) { EchoSenseTestPage() },
        LabPage(
            id: "test.connections",
            section: .test,
            group: "Databases",
            title: "Connections",
            symbol: "externaldrive.connected.to.line.below",
            summary: "Connect to the test servers through the real driver packages, run SQL and load a live schema."
        ) { ConnectionsTestPage() },
    ]
}
