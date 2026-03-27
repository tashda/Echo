import SwiftUI
import SQLServerKit

struct ExtendedEventsEditSheet: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetLayout(
            title: "Edit Session",
            icon: "pencil",
            subtitle: "Modify an Extended Events session.",
            primaryAction: "Save Changes",
            canSubmit: !viewModel.editEvents.isEmpty && !viewModel.isSavingEdits && hasChanges,
            isSubmitting: viewModel.isSavingEdits,
            errorMessage: viewModel.editErrorMessage,
            onSubmit: { await viewModel.saveEditSession() },
            onCancel: { dismiss() }
        ) {
            Form {
                sessionInfoSection
                if viewModel.editWasRunning {
                    runningWarningSection
                }
                eventsSection
                targetsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 560, height: 580)
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
                        .font(TypographyTokens.Table.sql)
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

    private var hasChanges: Bool {
        let diff = viewModel.computeEditDiff()
        return !diff.eventsToAdd.isEmpty || !diff.eventsToDrop.isEmpty
    }
}
