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
            id: "test.scenarios",
            section: .test,
            group: "EchoSense",
            title: "Scenarios",
            symbol: "checklist",
            summary: "Every scenario, one by one: what should happen, the expected result and the actual one from the real engine. The same scenarios run in the package's tests."
        ) { ScenariosTestPage() },
        LabPage(
            id: "test.tryquery",
            section: .test,
            group: "EchoSense",
            title: "Try SQL",
            symbol: "text.cursor",
            summary: "Write a query on a sample or live schema, see what EchoSense does at the caret, write what you expected, and save it as a scenario."
        ) { ScenarioPlaygroundPage() },
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
