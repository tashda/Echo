import SwiftUI

/// An area's numbered spec, read from its As built page, so every claim on the page has an ID
/// that feedback can point at (`WIN-3.2`) before the area is regrouped by piece.
///
/// Parts: 1 Behaviour, 2 Motion, 3 Measurements, 4 Rules. Numbers follow the order of the rows
/// in the As built page, so **append new rows; never insert, reorder or delete them**. When an
/// area is checked piece by piece, write a hand-made `AreaSpec` (as Tabs has) and pass it as
/// the area's `spec` instead.
extension LabArea {
    func withDerivedSpec(code: String) -> LabArea {
        guard spec == nil else { return self }
        let page = asBuilt
        guard !page.behaviours.isEmpty || !page.measurements.isEmpty else { return self }
        var copy = self
        var derived = AreaSpec(code: code, stageHeight: page.stageHeight, parts: Self.parts(from: page)) { page.specimen() }
        if let controls = page.controls { derived = derived.controls { controls() } }
        copy.spec = derived
        return copy
    }

    private static func parts(from page: AsBuiltPage) -> [SpecPart] {
        var parts: [SpecPart] = []
        if !page.behaviours.isEmpty {
            parts.append(SpecPart(number: "1", name: "Behaviour", summary: "What happens when you do something.",
                elements: page.behaviours.enumerated().map { index, item in
                    SpecElement(number: "1.\(index + 1)", name: item.trigger, summary: item.result,
                                groups: [.behaviour(.row("When", item.trigger), .row("Then", item.result))])
                }))
        }
        if !page.motions.isEmpty {
            parts.append(SpecPart(number: "2", name: "Motion", summary: "What moves, and how.",
                elements: page.motions.enumerated().map { index, item in
                    var rows = [SpecRow.row("Curve", item.curve), .row("Duration", item.duration)]
                    if let note = item.note { rows.append(.row("Where", note)) }
                    return SpecElement(number: "2.\(index + 1)", name: item.name, summary: item.curve + ", " + item.duration,
                                       groups: [SpecGroup(title: "Motion", rows: rows)])
                }))
        }
        if !page.measurements.isEmpty {
            parts.append(SpecPart(number: "3", name: "Measurements", summary: "Sizes, fonts, colours and the tokens that hold them.",
                elements: page.measurements.enumerated().map { index, item in
                    SpecElement(number: "3.\(index + 1)", name: item.label, summary: item.value,
                                groups: [.layout(.row(item.label, item.value, token: item.token))])
                }))
        }
        if !page.rules.isEmpty {
            parts.append(SpecPart(number: "4", name: "Rules", summary: "Decisions and why they were made.",
                elements: page.rules.enumerated().map { index, item in
                    SpecElement(number: "4.\(index + 1)", name: item.text, summary: item.why,
                                groups: [SpecGroup(title: "Why", rows: [.row("Decision", item.text), .row("Reason", item.why)])],
                                rounds: item.rounds)
                }))
        }
        return parts
    }
}
