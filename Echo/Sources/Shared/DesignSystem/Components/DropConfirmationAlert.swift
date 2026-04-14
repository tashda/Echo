import SwiftUI

/// Reusable drop/delete confirmation alert for database objects.
/// Usage: `.dropConfirmationAlert(objectType: "Schema", objectName: $pendingName, onDrop: { name in ... })`
struct DropConfirmationAlertModifier: ViewModifier {
    let objectType: String
    @Binding var objectName: String?
    var cascade: Bool = false
    let onDrop: (String) -> Void

    private var isPresented: Binding<Bool> {
        Binding(
            get: { objectName != nil },
            set: { if !$0 { objectName = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert("Drop \(objectType)?", isPresented: isPresented) {
                Button("Cancel", role: .cancel) {}
                Button("Drop", role: .destructive) {
                    if let name = objectName {
                        onDrop(name)
                    }
                }
            } message: {
                if cascade {
                    Text("Are you sure you want to drop the \(objectType.lowercased()) \"\(objectName ?? "")\" and all its dependent objects? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to drop the \(objectType.lowercased()) \"\(objectName ?? "")\"? This action cannot be undone.")
                }
            }
    }
}

extension View {
    /// Attaches a confirmation alert for dropping a database object.
    func dropConfirmationAlert(
        objectType: String,
        objectName: Binding<String?>,
        cascade: Bool = false,
        onDrop: @escaping (String) -> Void
    ) -> some View {
        modifier(DropConfirmationAlertModifier(
            objectType: objectType,
            objectName: objectName,
            cascade: cascade,
            onDrop: onDrop
        ))
    }
}
