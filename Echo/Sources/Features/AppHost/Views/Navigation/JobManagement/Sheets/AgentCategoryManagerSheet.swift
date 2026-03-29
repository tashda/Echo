import SwiftUI

/// Sheet for managing SQL Server Agent job categories — list, add, rename, delete.
struct AgentCategoryManagerSheet: View {
    let categories: [String]
    let onCreate: (String) async -> String?
    let onRename: (String, String) async -> String?
    let onDelete: (String) async -> String?
    let onDismiss: () -> Void

    @State private var newName: String = ""
    @State private var editingCategory: String?
    @State private var editedName: String = ""
    @State private var pendingDeleteCategory: String?
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        SheetLayout(
            title: "Manage Job Categories",
            primaryAction: "Done",
            canSubmit: true,
            errorMessage: errorMessage,
            onSubmit: { onDismiss() },
            onCancel: { onDismiss() }
        ) {
            VStack(spacing: 0) {
                categoryList
                Divider()
                addSection
            }
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 360)
        .alert("Delete Category?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { pendingDeleteCategory = nil }
            Button("Delete", role: .destructive) {
                guard let name = pendingDeleteCategory else { return }
                pendingDeleteCategory = nil
                Task { await performDelete(name) }
            }
        } message: {
            if let name = pendingDeleteCategory {
                Text("Are you sure you want to delete category \"\(name)\"? Jobs using this category will be moved to the default category.")
            }
        }
    }

    private var categoryList: some View {
        List {
            if categories.isEmpty {
                Text("No custom categories")
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .font(TypographyTokens.detail)
            } else {
                ForEach(categories, id: \.self) { category in
                    categoryRow(category)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    @ViewBuilder
    private func categoryRow(_ category: String) -> some View {
        if editingCategory == category {
            HStack {
                TextField("Name", text: $editedName, prompt: Text("Category name"))
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await performRename(category) } }

                Button {
                    Task { await performRename(category) }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Status.success)
                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    editingCategory = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Text.tertiary)
            }
        } else {
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(ColorTokens.Text.secondary)
                Text(category)
                    .font(TypographyTokens.standard)
                Spacer()
            }
            .contextMenu {
                Button {
                    editingCategory = category
                    editedName = category
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }

                Divider()

                Button(role: .destructive) {
                    pendingDeleteCategory = category
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var addSection: some View {
        HStack(spacing: SpacingTokens.xs) {
            TextField("New category", text: $newName, prompt: Text("e.g. Database Maintenance"))
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    Task { await performCreate() }
                }

            Button {
                Task { await performCreate() }
            } label: {
                Label("Add", systemImage: "plus.circle")
            }
            .controlSize(.small)
            .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)

            if isWorking {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(SpacingTokens.sm)
    }

    // MARK: - Actions

    private func performCreate() async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isWorking = true
        let error = await onCreate(trimmed)
        isWorking = false
        if let error { errorMessage = error; return }
        newName = ""
        errorMessage = nil
    }

    private func performRename(_ original: String) async {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != original else {
            editingCategory = nil
            return
        }
        isWorking = true
        let error = await onRename(original, trimmed)
        isWorking = false
        if let error { errorMessage = error; return }
        editingCategory = nil
        errorMessage = nil
    }

    private func performDelete(_ name: String) async {
        isWorking = true
        let error = await onDelete(name)
        isWorking = false
        if let error { errorMessage = error; return }
        errorMessage = nil
    }
}
