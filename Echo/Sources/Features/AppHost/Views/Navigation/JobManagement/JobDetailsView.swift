import SwiftUI

struct JobDetailsView: View {
    var viewModel: JobQueueViewModel
    let notificationEngine: NotificationEngine?

    // Properties editing
    @State var editingProps: JobQueueViewModel.PropertySheet?

    // Step editing
    @State var newStepName = ""
    @State var newStepSubsystem = "TSQL"
    @State var newStepDatabase = ""
    @State var newStepCommand = ""
    @State var selectedStepID: Int?

    // Command editor sheet (item-based for reliable data passing)
    @State var commandEditorContext: CommandEditorContext?

    // Schedule editing
    @State var newScheduleName = ""
    @State var newScheduleEnabled = true
    @State var newScheduleFrequency: ScheduleFrequency = .daily
    @State var newScheduleInterval = 1
    @State var newScheduleStartHour = 9
    @State var newScheduleStartMinute = 0
    @State var newScheduleWeekdays: Set<Int> = [2] // Monday
    @State var newScheduleMonthDay = 1
    @State var newScheduleStartDate = Date()
    @State var newScheduleOneTimeDate = Date()
    @State var selectedScheduleID: Set<String> = []

    // Notification editing
    @State var notifyOperator = ""
    @State var notifyLevel = 0 // 0=Never, 1=Success, 2=Failure, 3=Completion
    @State var notifyEventLogLevel = 0
    @State var notificationsLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Details")
                    .font(TypographyTokens.prominent.weight(.semibold))
                Spacer()
                if viewModel.isLoadingDetails {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.sm)

            if viewModel.properties != nil {
                TabView {
                    propertiesTab
                        .tabItem { Label("Properties", systemImage: "info.circle") }
                    stepsTab
                        .tabItem { Label("Steps", systemImage: "list.number") }
                    schedulesTab
                        .tabItem { Label("Schedules", systemImage: "calendar") }
                    notificationsTab
                        .tabItem { Label("Notifications", systemImage: "bell") }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedJobID != nil {
                VStack {
                    ProgressView()
                    Text(viewModel.errorMessage == nil ? "Loading details..." : viewModel.errorMessage!)
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
                notificationEngine?.post(category: .jobError, message: error, duration: 5.0)
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
            onUseCommand: { text in
                newStepCommand = text
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
