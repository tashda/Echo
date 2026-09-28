import SwiftUI
import ActiveDirectory

/// Browse Active Directory — single-pane SSMS-equivalent layout. Object Types
/// + Location filters live above an inline search field; results sit below.
/// No sidebar, no toolbar search slot — everything is on one surface so the
/// flow matches what Windows users expect.
struct WindowsPrincipalPickerSheet: View {

    @Bindable var viewModel: WindowsPrincipalPickerViewModel
    let onConfirm: ([ADPrincipal]) -> Void
    let onCancel: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            controlsSection
            Divider()
            resultsTable
            Divider()
            footer
        }
        .frame(minWidth: 720, idealWidth: 860, minHeight: 480, idealHeight: 580)
        .background(ColorTokens.Background.primary)
        .task { await viewModel.connect() }
        .task {
            // Focus the search field when the window opens so the user can
            // start typing immediately.
            try? await Task.sleep(for: .milliseconds(50))
            searchFocused = true
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            Text("Select Active Directory Principal")
                .font(TypographyTokens.headline)

            FormRow(label: "Object types") {
                HStack(spacing: SpacingTokens.md) {
                    Toggle("Users", isOn: $viewModel.includeUsers)
                    Toggle("Groups", isOn: $viewModel.includeGroups)
                    Toggle("Computers", isOn: $viewModel.includeComputers)
                }
                .toggleStyle(.checkbox)
            }

            FormRow(label: "Location") {
                Picker("", selection: $viewModel.selectedScopeID) {
                    ForEach(viewModel.scopes) { scope in
                        Text(scope.displayName).tag(scope.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)
                .disabled(viewModel.scopes.isEmpty)
            }

            FormRow(label: "Find") {
                HStack(spacing: SpacingTokens.sm) {
                    TextField(
                        "",
                        text: $viewModel.searchText,
                        prompt: Text("Name, login, or email")
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .onSubmit { Task { await viewModel.runSearch() } }
                    .frame(maxWidth: .infinity)

                    Button("Find Now") {
                        Task { await viewModel.runSearch() }
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(viewModel.status == .connecting || viewModel.status == .searching)
                }
            }
        }
        .padding(SpacingTokens.md)
    }

    // MARK: - Results

    private var resultsTable: some View {
        Table(viewModel.results, selection: $viewModel.selectedDNs) {
            TableColumn("Name") { p in
                Text(p.sAMAccountName).font(TypographyTokens.standard)
            }.width(min: 140, ideal: 180)
            TableColumn("Display Name") { p in
                Text(p.displayName ?? "—").font(TypographyTokens.standard)
            }.width(min: 160, ideal: 220)
            TableColumn("Domain") { p in
                Text(viewModel.displayDomain(for: p)).font(TypographyTokens.detail)
            }.width(min: 100, ideal: 140)
            TableColumn("Type") { p in
                Text(typeLabel(for: p.objectClass)).font(TypographyTokens.detail)
            }.width(min: 70, ideal: 90)
        }
        // Double-click confirms with that row (and that row only). Single-
        // selection at the click site — even if the user had a multi-
        // selection accumulating, the row they double-clicked is what
        // they're picking.
        .contextMenu(forSelectionType: String.self, menu: { _ in EmptyView() }) { selection in
            let picked = viewModel.results.filter { selection.contains($0.distinguishedName) }
            if !picked.isEmpty {
                onConfirm(picked)
            }
        }
        .overlay(stateOverlay)
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.status {
        case .connecting:
            connectingOverlay
        case .searching:
            searchingOverlay
        case let .error(message):
            ContentUnavailableView {
                Label("Couldn't search Active Directory", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message).textSelection(.enabled)
            }
        case .ready where viewModel.results.isEmpty && viewModel.hasRunSearch:
            ContentUnavailableView.search(text: viewModel.lastSearchedText)
        case .ready where viewModel.results.isEmpty:
            preSearchOverlay
        default:
            EmptyView()
        }
    }

    private var connectingOverlay: some View {
        VStack(spacing: SpacingTokens.sm) {
            ProgressView()
            Text("Connecting to Active Directory")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchingOverlay: some View {
        VStack(spacing: SpacingTokens.sm) {
            ProgressView()
            Text("Searching \(viewModel.selectedScopeDisplayName)")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary.opacity(0.85))
    }

    private var preSearchOverlay: some View {
        ContentUnavailableView {
            Label("Search Active Directory", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            Text("Type a name, login, or email above and press Return to look up users and groups in \(viewModel.selectedScopeDisplayName).")
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            statusLine
            Spacer()
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button("OK") {
                onConfirm(viewModel.selectedPrincipals)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.selectedDNs.isEmpty)
        }
        .padding(SpacingTokens.md)
    }

    @ViewBuilder
    private var statusLine: some View {
        if viewModel.truncated {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                Text("Showing the first 500 results — narrow your search to see more")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
            }
        } else {
            Text(selectionSummary)
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.Text.secondary)
        }
    }

    private var selectionSummary: String {
        switch viewModel.selectedDNs.count {
        case 0:
            if viewModel.hasRunSearch {
                return "\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s")"
            }
            return ""
        case 1: return "1 selected"
        case let n: return "\(n) selected"
        }
    }

    private func typeLabel(for objectClass: ADPrincipal.ObjectClass) -> String {
        switch objectClass {
        case .user: return "User"
        case .group: return "Group"
        case .computer: return "Computer"
        case .organizationalUnit: return "OU"
        case let .other(name): return name.capitalized
        }
    }
}

// MARK: - FormRow

/// Aligned label-on-left form rows. Each label has a fixed width so the
/// controls line up vertically — matches the SSMS Select User/Group dialog
/// and the rest of Echo's grouped property forms.
private struct FormRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.md) {
            Text(label)
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 96, alignment: .trailing)
            content()
            Spacer(minLength: 0)
        }
    }
}
