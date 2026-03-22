import SwiftUI
import SQLServerKit

struct ExtendedEventsCreateSheet: View {
    @Bindable var viewModel: ExtendedEventsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                eventsSection
                targetSection
                optionsSection

                if let error = viewModel.createErrorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            actionButtons
        }
        .frame(width: 560, height: 580)
        .task { await viewModel.loadAvailableEvents() }
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            TextField("Session Name", text: $viewModel.createSessionName, prompt: Text("e.g. SlowQueries"))
        } header: {
            Text("New Extended Events Session")
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

            addEventControls
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
                viewModel.removeEventEntry(entry.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(ColorTokens.Status.error)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove Event")
        }
    }

    @ViewBuilder
    private var addEventControls: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                eventPicker
                Button("Add") {
                    viewModel.addEventEntry()
                }
                .disabled(viewModel.newEventName.isEmpty)
            }

            if !viewModel.newEventName.isEmpty {
                actionToggles
                predicateField
            }
        }
    }

    private var eventPicker: some View {
        Group {
            if viewModel.availableEvents.isEmpty {
                Picker("Event", selection: $viewModel.newEventName) {
                    Text("Select event\u{2026}").tag("")
                    Section("Common") {
                        Text("sql_statement_completed").tag("sqlserver.sql_statement_completed")
                        Text("rpc_completed").tag("sqlserver.rpc_completed")
                        Text("sql_batch_completed").tag("sqlserver.sql_batch_completed")
                        Text("error_reported").tag("sqlserver.error_reported")
                        Text("wait_completed").tag("sqlos.wait_completed")
                        Text("lock_deadlock").tag("sqlserver.lock_deadlock")
                    }
                }
            } else {
                let grouped = Dictionary(grouping: viewModel.availableEvents, by: \.packageName)
                let packages = grouped.keys.sorted()

                Picker("Event", selection: $viewModel.newEventName) {
                    Text("Select event\u{2026}").tag("")
                    ForEach(packages, id: \.self) { pkg in
                        Section(pkg) {
                            ForEach(grouped[pkg] ?? [], id: \.id) { event in
                                Text(event.eventName).tag(event.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionToggles: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            Text("Actions")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)

            FlowLayout(spacing: SpacingTokens.xxs2) {
                ForEach(commonActions, id: \.self) { action in
                    let shortName = action.replacingOccurrences(of: "sqlserver.", with: "")
                    Toggle(shortName, isOn: Binding(
                        get: { viewModel.newEventActions.contains(action) },
                        set: { if $0 { viewModel.newEventActions.insert(action) } else { viewModel.newEventActions.remove(action) } }
                    ))
                    .toggleStyle(.checkbox)
                    .font(TypographyTokens.detail)
                }
            }
        }
    }

    private var predicateField: some View {
        TextField("WHERE predicate (optional)", text: $viewModel.newEventPredicate, prompt: Text("e.g. duration > 1000000"))
            .font(.system(size: 11, design: .monospaced))
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

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Create") {
                Task { await viewModel.createSession() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.createSessionName.isEmpty || viewModel.createEvents.isEmpty || viewModel.isCreating)
        }
        .padding(SpacingTokens.md)
    }

    // MARK: - Constants

    private var commonActions: [String] {
        [
            "sqlserver.sql_text",
            "sqlserver.database_name",
            "sqlserver.username",
            "sqlserver.client_hostname",
            "sqlserver.client_app_name",
            "sqlserver.session_id",
            "sqlserver.query_hash",
            "sqlserver.plan_handle"
        ]
    }
}
