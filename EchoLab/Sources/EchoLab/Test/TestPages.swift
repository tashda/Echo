import EchoSenseScenarios
import SwiftUI

/// Interactive pages that call the real packages: EchoSense, connections, drivers.
@MainActor
enum TestPages {
    /// One page per kind of scenario (statements, GO batches, ...), from the package's domain list.
    static let domainPages: [LabPage] = ScenarioDomains.all.map { domain in
        LabPage(
            id: "test.domain.\(domain.id)",
            section: .test,
            group: "Scripts and results",
            title: domain.title,
            symbol: "checklist",
            summary: domain.summary + " The same scenarios run in EchoSense's tests."
        ) { DomainScenariosPage(domain: domain) }
    }

    static let all: [LabPage] = base + domainPages

    private static let base: [LabPage] = [
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
            summary: "Every scenario, one by one: what should happen, the checks it makes and whether the real engine passes them. The same checks run in the package's tests.",
            ownsHeader: true
        ) { ScenariosTestPage() },
        LabPage(
            id: "test.referee",
            section: .test,
            group: "EchoSense",
            title: "Popup Referee",
            symbol: "flag.checkered",
            summary: "The scenarios as a game against the live engine: set the rule from blocks, see the real popup with every row's kind, and call whether it follows the rule.",
            ownsHeader: true
        ) { RefereePage() },
        LabPage(
            id: "test.tryquery",
            section: .test,
            group: "EchoSense",
            title: "Try SQL",
            symbol: "text.cursor",
            summary: "Write a query on a sample or live schema, see what EchoSense does at the caret, write what you expected, and save it as a scenario."
        ) { ScenarioPlaygroundPage() },
        LabPage(
            id: "test.servers",
            section: .test,
            group: "Databases",
            title: "Servers",
            symbol: "server.rack",
            summary: "Start disposable database servers from echo-server-lab recipes on testlab, see what runs there and how much memory is used, and watch builds."
        ) { ServersTestPage() },
        LabPage(
            id: "test.tds",
            section: .test,
            group: "Databases",
            title: "TDS reference",
            symbol: "doc.text.magnifyingglass",
            summary: "Explain TDS bytes field by field with the lab's decoder and look up MS-TDS tokens, types, messages and flows (the tds-mcp tools)."
        ) { TDSReferencePage() },
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
