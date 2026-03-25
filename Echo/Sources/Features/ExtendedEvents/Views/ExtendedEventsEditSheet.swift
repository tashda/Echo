import SwiftUI
import SQLServerKit

struct ExtendedEventsEditSheet: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                sessionInfoSection
                if viewModel.editWasRunning {
                    runningWarningSection
                }
                eventsSection
                targetsSection

                if let error = viewModel.editErrorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()
            footerButtons
        }
        .frame(width: 560, height: 580)
        .navigationTitle("Edit Session")
        .task { await viewModel.loadAvailableEvents() }
    }

    // MARK: - Session Info

    private var sessionInfoSection: some View {
        Section {
            PropertyRow(title: "Session Name") {
                Text(viewModel.editingSessionName ?? "")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        } header: {
            Text("Session")
        }
    }

    // MARK: - Running Warning

    private var runningWarningSection: some View {
        Section {
            PermissionBanner(
                message: "This session is running. It will be stopped while changes are applied, then restarted.",
                severity: .readOnly
            )
        }
    }

    // MARK: - Events

    private var eventsSection: some View {
        Section {
            if viewModel.editEvents.isEmpty {
                Text("No events configured. Add at least one event.")
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(viewModel.editEvents) { entry in
                    eventRow(entry)
                }
            }

            ExtendedEventsEventControls(viewModel: viewModel) {
                viewModel.addEditEventEntry()
            }
        } header: {
            Text("Events")
        }
    }

    private func eventRow(_ entry: ExtendedEventsViewModel.EventEntry) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                Text(entry.eventName)
                    .font(TypographyTokens.standard.weight(.medium))

                if !entry.actions.isEmpty {
                    Text("Actions: \(entry.actions.map { $0.replacingOccurrences(of: "sqlserver.", with: "") }.joined(separator: ", "))")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                if let predicate = entry.predicate {
                    Text("WHERE \(predicate)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            Spacer()

            Button {
                viewModel.removeEditEvent(entry.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove Event")
        }
    }

    // MARK: - Targets

    private var targetsSection: some View {
        Section {
            if viewModel.editTargets.isEmpty {
                Text("No targets configured.")
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(viewModel.editTargets) { target in
                    HStack {
                        Text(target.targetName)
                            .font(TypographyTokens.standard.weight(.medium))
                        Spacer()
                    }
                }
            }
        } header: {
            Text("Targets")
        }
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: SpacingTokens.sm) {
            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button("Save Changes") {
                Task { await viewModel.saveEditSession() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.editEvents.isEmpty || viewModel.isSavingEdits || !hasChanges)
        }
        .padding(.horizontal, SpacingTokens.md2)
        .padding(.vertical, SpacingTokens.sm2)
        .background(.bar)
    }

    private var hasChanges: Bool {
        let diff = viewModel.computeEditDiff()
        return !diff.eventsToAdd.isEmpty || !diff.eventsToDrop.isEmpty
    }
}
