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
        ) { EchoSenseTestPage() }
    ]
}
