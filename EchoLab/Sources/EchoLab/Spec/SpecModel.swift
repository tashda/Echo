import SwiftUI

/// The detailed spec of an area: every part and every element in it, each with a stable ID.
///
/// IDs are `AREA-part.element`: `TABS-2` is the Tab part and `TABS-2.4` is its active fill.
/// Numbers are never reused or renumbered; a retired element stays, struck through, so old
/// feedback keeps pointing at the right thing.
@MainActor
struct AreaSpec {
    /// Short code used in IDs, such as "TABS".
    let code: String
    let parts: [SpecPart]
    /// The live specimen; parts of it carry `.specAnchor("2.4")` so their IDs can be shown.
    let specimen: () -> AnyView
    var controls: (() -> AnyView)?
    var stageHeight: CGFloat = 200

    init<Specimen: View>(code: String, stageHeight: CGFloat = 200, parts: [SpecPart], @ViewBuilder specimen: @escaping () -> Specimen) {
        self.code = code
        self.parts = parts
        self.stageHeight = stageHeight
        self.specimen = { AnyView(specimen()) }
    }

    func controls<Controls: View>(@ViewBuilder _ controls: @escaping () -> Controls) -> AreaSpec {
        var copy = self
        copy.controls = { AnyView(controls()) }
        return copy
    }

    func id(_ number: String) -> String { "\(code)-\(number)" }

    func element(number: String) -> SpecElement? { parts.flatMap(\.elements).first { $0.number == number } }
    func part(number: String) -> SpecPart? { parts.first { $0.number == number } }
}

struct SpecPart: Identifiable {
    /// "2".
    let number: String
    let name: String
    let summary: String
    let elements: [SpecElement]
    var id: String { number }
}

struct SpecElement: Identifiable {
    /// "2.4": part, then element.
    let number: String
    let name: String
    let summary: String
    var groups: [SpecGroup] = []
    /// Round pages that decided or shaped it (`LabPage.id`).
    var rounds: [String] = []
    var files: [String] = []
    var isRetired = false
    var id: String { number }
}

/// A block of properties: Type, Layout, Material, States, Motion, Behaviour, Accessibility.
struct SpecGroup: Identifiable {
    let title: String
    let rows: [SpecRow]
    var id: String { title }
}

struct SpecRow: Identifiable {
    let label: String
    let value: String
    /// The token or constant that holds the value in code.
    var token: String?
    /// A live colour, read from the token itself so it can't drift.
    var swatch: Color?
    var id: String { label }
}

extension SpecGroup {
    static func type(_ rows: SpecRow...) -> SpecGroup { SpecGroup(title: "Type", rows: rows) }
    static func layout(_ rows: SpecRow...) -> SpecGroup { SpecGroup(title: "Layout", rows: rows) }
    static func material(_ rows: SpecRow...) -> SpecGroup { SpecGroup(title: "Material", rows: rows) }
    static func states(_ rows: SpecRow...) -> SpecGroup { SpecGroup(title: "States", rows: rows) }
    static func motion(_ rows: SpecRow...) -> SpecGroup { SpecGroup(title: "Motion", rows: rows) }
    static func behaviour(_ rows: SpecRow...) -> SpecGroup { SpecGroup(title: "Behaviour", rows: rows) }
}

extension SpecRow {
    static func row(_ label: String, _ value: String, token: String? = nil, swatch: Color? = nil) -> SpecRow {
        SpecRow(label: label, value: value, token: token, swatch: swatch)
    }
}
