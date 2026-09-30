import SwiftUI

/// Interactive pages that call the real packages: EchoSense, connections, drivers.
@MainActor enum TestPages {
    static let all: [LabPage] = [
        LabPage(
            id: "test.overview",
            section: .test,
            group: "Packages",
            title: "Overview",
            symbol: "testtube.2",
            summary: "Try EchoSense, connect to databases and call the drivers directly."
        ) {
            ContentUnavailableView(
                "No test pages yet",
                systemImage: "testtube.2",
                description: Text("EchoSense, Connections and Drivers pages come after the Design Lab port.")
            )
        }
    ]
}
