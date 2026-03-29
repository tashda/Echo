import SwiftUI
import SQLServerKit

struct ExtendedEventsCreateSheet: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(EnvironmentState.self) private var environmentState

    private var canCreate: Bool {
        !viewModel.createSessionName.isEmpty
            && !viewModel.createEvents.isEmpty
            && !viewModel.isCreating
            && (environmentState.sessionGroup.activeSessions.first { $0.id == viewModel.connectionSessionID }?.permissions?.canManageServerState ?? true)
    }

    var body: some View {
        SheetLayout(
            title: "New Extended Events Session",
            icon: "bolt.horizontal",
            subtitle: "Create a session to capture and analyze server events.",
            primaryAction: "Create",
            canSubmit: canCreate,
            isSubmitting: viewModel.isCreating,
            errorMessage: viewModel.createErrorMessage,
            onSubmit: { await viewModel.createSession() },
            onCancel: { dismiss() }
        ) {
            Form {
                generalSection
                eventsSection
                targetSection
                optionsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 560, height: 580)
        .task { await viewModel.loadAvailableEvents() }
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            TextField("Session Name", text: $viewModel.createSessionName, prompt: Text("e.g. SlowQueries"))
        } header: {
            Text("General")
        }
    }

    // MARK: - Events

    private var eventsSection: some View {
        Section {
            if viewModel.createEvents.isEmpty {
                Text("No events added yet. Add at least one event below.")
                    .foregroundStyle(ColorTokens.Text.tertiary)
            } else {
                ForEach(viewModel.createEvents) { entry in
                    eventRow(entry)
                }
            }

            ExtendedEventsEventControls(viewModel: viewModel) {
                viewModel.addEventEntry()
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
                viewModel.removeEventEntry(entry.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove Event")
        }
    }

    // MARK: - Target

    private var targetSection: some View {
        Section {
            Picker("Target", selection: $viewModel.createTargetType) {
                ForEach(ExtendedEventsViewModel.TargetChoice.allCases, id: \.self) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }

            switch viewModel.createTargetType {
            case .ringBuffer:
                TextField("Max Memory (KB)", value: $viewModel.createRingBufferKB, format: .number, prompt: Text("4096"))
            case .eventFile:
                TextField("File Name", text: $viewModel.createEventFileName, prompt: Text("e.g. /var/log/xe_session"))
                TextField("Max File Size (MB)", value: $viewModel.createEventFileMaxMB, format: .number, prompt: Text("100"))
            }
        } header: {
            Text("Target")
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        Section {
            TextField("Session Memory (KB)", value: $viewModel.createMaxMemoryKB, format: .number, prompt: Text("4096"))
            Toggle("Start with Server", isOn: $viewModel.createStartupState)
        } header: {
            Text("Options")
        }
    }
}
