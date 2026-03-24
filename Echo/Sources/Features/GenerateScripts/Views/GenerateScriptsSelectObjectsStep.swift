import SwiftUI
import SQLServerKit

/// Step 1 of the Generate Scripts wizard: object selection tree with category checkboxes.
struct GenerateScriptsSelectObjectsStep: View {
    @Bindable var viewModel: GenerateScriptsWizardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar

            Divider()

            if viewModel.isLoadingObjects {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                objectTree
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("Select objects to script:")
                .font(TypographyTokens.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Select All") { viewModel.selectAll() }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail)
                .foregroundStyle(Color.accentColor)
            Text("/")
                .foregroundStyle(.tertiary)
                .font(TypographyTokens.detail)
            Button("Deselect All") { viewModel.deselectAll() }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    // MARK: - Object Tree

    private var objectTree: some View {
        List {
            ForEach(viewModel.objectsByCategory, id: \.category) { group in
                DisclosureGroup {
                    ForEach(group.objects, id: \.self) { obj in
                        objectRow(obj)
                    }
                } label: {
                    categoryRow(group.category, count: group.objects.count)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Rows

    private func categoryRow(_ category: String, count: Int) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Toggle(isOn: Binding(
                get: { viewModel.isAllSelected(in: category) },
                set: { _ in viewModel.toggleAll(in: category) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: iconForCategory(category))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(category)
                .font(TypographyTokens.formLabel)

            Text("\(count)")
                .font(TypographyTokens.detail)
                .foregroundStyle(.tertiary)
        }
    }

    private func objectRow(_ obj: SQLServerObjectIdentifier) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Toggle(isOn: Binding(
                get: { viewModel.selectedObjectIDs.contains(obj) },
                set: { _ in viewModel.toggleObject(obj) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text(obj.qualifiedName)
                .font(TypographyTokens.standard)
                .lineLimit(1)
        }
        .padding(.leading, SpacingTokens.md)
    }

    // MARK: - Icons

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Tables": return "tablecells"
        case "Views": return "eye"
        case "Stored Procedures": return "gearshape.fill"
        case "Functions": return "function"
        case "Triggers": return "bolt.fill"
        case "Synonyms": return "arrow.triangle.branch"
        case "Types": return "textformat"
        case "Sequences": return "number"
        default: return "cube"
        }
    }
}
