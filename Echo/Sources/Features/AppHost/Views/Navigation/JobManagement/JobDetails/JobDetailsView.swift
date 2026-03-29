import SwiftUI

struct JobDetailsView: View {
    var viewModel: JobQueueViewModel
    let notificationEngine: NotificationEngine?

    // Properties editing
    @State var editingProps: JobQueueViewModel.PropertySheet?

    // Step editing
    @State var showAddStepSheet = false
    @State var editingStep: JobQueueViewModel.StepRow?
    @State var selectedStepID: Int?
    @State var showDeleteStepAlert = false
    @State var pendingDeleteStepName: String?

    // Command editor sheet (item-based for reliable data passing)
    @State var commandEditorContext: CommandEditorContext?

    // Schedule editing
    @State var showAddScheduleSheet = false
    @State var selectedScheduleID: Set<String> = []

    enum DetailSection: String, CaseIterable, Identifiable {
        case properties = "Properties"
        case steps = "Steps"
        case schedules = "Schedules"
        case notifications = "Notifications"
        var id: String { rawValue }
    }

    // Notification editing
    @State var notifyOperator = ""
    @State var notifyLevel = 0 // 0=Never, 1=Success, 2=Failure, 3=Completion
    @State var notifyEventLogLevel = 0
    @State var notificationsLoaded = false
    @State var showEditNotificationSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Details")
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)

            if viewModel.properties != nil {
                Picker("", selection: Binding(
                    get: { DetailSection(rawValue: viewModel.selectedDetailSection) ?? .properties },
                    set: { viewModel.selectedDetailSection = $0.rawValue }
                )) {
                    ForEach(DetailSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, SpacingTokens.xs)

                Group {
                    let currentSection = DetailSection(rawValue: viewModel.selectedDetailSection) ?? .properties
                    switch currentSection {
                    case .properties: propertiesTab
                    case .steps: stepsTab
                    case .schedules: schedulesTab
                    case .notifications: notificationsTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedJobID != nil {
                VStack {
                    ProgressView()
                    Text(viewModel.errorMessage ?? "Loading details...")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select a job to view details.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $commandEditorContext) { context in
            commandEditorSheet(context: context)
        }
        .onChange(of: viewModel.properties) { _, _ in
            // Clear local editing state when server data refreshes
            editingProps = nil
        }
        .onChange(of: viewModel.errorMessage) { _, error in
            if let error {
                // Suppress notification for permission-denied errors — the PermissionBanner
                // already communicates this to the user.
                let isPermissionError = error.localizedLowercase.contains("permission was denied")
                    || error.localizedLowercase.contains("not have permission")
                if !isPermissionError {
                    notificationEngine?.post(category: .jobError, message: error, duration: 5.0)
                }
                viewModel.errorMessage = nil
            }
        }
    }

    // MARK: - Command Editor Sheet

    private func commandEditorSheet(context: CommandEditorContext) -> some View {
        CommandEditorView(
            context: context,
            onSaveToStep: { stepName, text in
                Task {
                    await viewModel.updateStep(stepName: stepName, newCommand: text, database: nil)
                    commandEditorContext = nil
                }
            },
            onUseCommand: { _ in
                commandEditorContext = nil
            },
            onCancel: {
                commandEditorContext = nil
            }
        )
    }

    // MARK: - Helpers

    func frequencyDisplayName(_ freqType: Int) -> String {
        switch freqType {
        case 1: return "Once"
        case 4: return "Daily"
        case 8: return "Weekly"
        case 16: return "Monthly"
        case 32: return "Monthly (relative)"
        case 64: return "Agent start"
        case 128: return "Idle"
        default: return "Unknown (\(freqType))"
        }
    }
}
