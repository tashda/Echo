import Observation

/// What is selected on the Spec page (a full ID such as "TABS-2.6", or "area:<id>" for an area
/// that has no numbered spec yet), remembered between launches.
@Observable @MainActor
final class LabSpecState {
    static let shared = LabSpecState()

    var selected: String? = LabPrefs.load("spec.selected", default: Optional<String>.none) {
        didSet { LabPrefs.save(selected, key: "spec.selected") }
    }
    /// The state chosen for the selected element (nil is at rest).
    var previewState: String?
    var expandedAreas: Set<String> = Set(LabPrefs.load("spec.expanded", default: ["tabs"])) {
        didSet { LabPrefs.save(Array(expandedAreas), key: "spec.expanded") }
    }

    /// The area an ID belongs to.
    func area(forSelection id: String?) -> LabArea? {
        guard let id else { return nil }
        if id.hasPrefix("area:") { return LabAreas.area(id: String(id.dropFirst(5))) }
        let code = id.split(separator: "-").first.map(String.init)
        return LabAreas.all.first { $0.spec?.code == code }
    }

    func element(forSelection id: String?) -> (area: LabArea, spec: AreaSpec, element: SpecElement)? {
        guard let id, !id.hasPrefix("area:"), let area = area(forSelection: id), let spec = area.spec else { return nil }
        let number = id.split(separator: "-", maxSplits: 1).last.map(String.init) ?? ""
        guard let element = spec.element(number: number) else { return nil }
        return (area, spec, element)
    }

    /// Selects an element and puts the specimen in the state that shows it.
    func select(_ id: String?) {
        selected = id
        previewState = element(forSelection: id)?.element.defaultState
        apply()
    }

    func setPreview(_ key: String?) {
        previewState = key
        apply()
    }

    func apply() {
        guard let found = element(forSelection: selected) else { return }
        found.spec.applyState?(previewState)
    }
}
