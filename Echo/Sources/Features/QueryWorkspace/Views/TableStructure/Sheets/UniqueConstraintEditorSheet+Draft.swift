import SwiftUI
import Foundation

extension UniqueConstraintEditorSheet {
    func applyDraftChanges() {
        constraint.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        constraint.columns = draft.columns.map { $0.name }
    }

    func cancelIfNew() {
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }

    func bindingForColumn(_ columnID: UUID) -> Binding<Draft.Column> {
        guard let index = draft.columns.firstIndex(where: { $0.id == columnID }) else {
            fatalError("Column not found")
        }
        return $draft.columns[index]
    }

    func columnOptionsForColumn(_ columnID: UUID) -> [String] {
        let selectedByOthers = Set(draft.columns.filter { $0.id != columnID }.map { $0.name })
        let options = availableColumns.filter { !selectedByOthers.contains($0) }
        if let current = draft.columns.first(where: { $0.id == columnID })?.name,
           !current.isEmpty,
           !options.contains(current) {
            return (options + [current]).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var computedAddableColumns: [String] {
        availableColumns.filter { name in
            !draft.columns.contains { $0.name == name }
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func addDraftColumn(named name: String) {
        draft.columns.append(.init(name: name))
    }

    func removeDraftColumn(withID id: UUID) {
        draft.columns.removeAll { $0.id == id }
    }

    func moveDraftColumn(at index: Int, by offset: Int) {
        let newIndex = index + offset
        guard newIndex >= 0 && newIndex < draft.columns.count else { return }
        withAnimation {
            draft.columns.move(fromOffsets: IndexSet(integer: index), toOffset: newIndex > index ? newIndex + 1 : newIndex)
        }
    }
}
