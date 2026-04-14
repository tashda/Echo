import Foundation

struct CommandEditorContext: Identifiable {
    let id = UUID()
    let stepName: String?
    let initialText: String
}
