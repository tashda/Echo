import SwiftUI

/// A minimal sheet for creating a new SQL Server Agent job category.
struct NewAgentCategorySheet: View {
    @Binding var categoryName: String
    @Binding var errorMessage: String?
    let onCreate: () -> Void
    let onCancel: () -> Void

    private var isValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SheetLayout(
            title: "New Job Category",
            icon: "folder.badge.plus",
            subtitle: "Create a category to organize SQL Agent jobs.",
            primaryAction: "Create",
            canSubmit: isValid,
            errorMessage: errorMessage,
            onSubmit: { onCreate() },
            onCancel: { onCancel() }
        ) {
            Form {
                Section("New Job Category") {
                    TextField("Name", text: $categoryName, prompt: Text("e.g. Database Maintenance"))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 360, minHeight: 180)
    }
}
