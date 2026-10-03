import SwiftUI
import AppKit
import StageCore

/// `--check`: the headless run Hatch does before a Proposal reaches the owner (decision S6). Every specimen is drawn in every
/// applicable scenario; the result is one JSON object on standard output, and the exit code is 0 only when all of them drew.
@MainActor
enum StageSelfCheck {
    struct Failure: Codable {
        var specimen: String
        var scenario: String
        var reason: String
    }

    struct Report: Codable {
        var ok: Bool
        var revision: Int
        var checked: Int
        var failures: [Failure]
    }

    static func run(provider: any SpecimenProvider, manifest: StageManifest) -> Int32 {
        _ = NSApplication.shared
        var failures: [Failure] = []
        var checked = 0
        let controls = manifest.defaultControlValues
        for specimen in manifest.specimens {
            for scenario in manifest.applicableScenarios {
                checked += 1
                if !provider.hasSpecimen(id: specimen.id) {
                    failures.append(Failure(specimen: specimen.id, scenario: scenario.id, reason: "This app has no specimen with this id."))
                    continue
                }
                var size = provider.designSize(for: specimen.id)
                if size.width <= 0 || size.height <= 0 {
                    size = CGSize(width: specimen.designWidth ?? 0, height: specimen.designHeight ?? 0)
                }
                if size.width <= 0 || size.height <= 0 {
                    failures.append(Failure(specimen: specimen.id, scenario: scenario.id, reason: "No design size."))
                    continue
                }
                let view = provider.specimenView(id: specimen.id, scenario: scenario.id, controls: controls)
                    .frame(width: size.width, height: size.height)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                if renderer.cgImage == nil {
                    failures.append(Failure(specimen: specimen.id, scenario: scenario.id, reason: "It did not draw."))
                }
            }
        }
        let report = Report(ok: failures.isEmpty, revision: manifest.revision, checked: checked, failures: failures)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(report) {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
        return report.ok ? 0 : 1
    }
}
