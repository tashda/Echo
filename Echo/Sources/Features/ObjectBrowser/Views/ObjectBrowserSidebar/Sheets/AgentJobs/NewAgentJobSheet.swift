import SwiftUI
import SQLServerKit

struct NewAgentJobSheet: View {
    let session: ConnectionSession
    let environmentState: EnvironmentState
    let onComplete: () -> Void

    @State var jobName = ""
    @State var jobDescription = ""
    @State var jobEnabled = true
    @State var jobOwner = ""
    @State var jobCategory = ""
    @State var startAfterCreate = false

    // Steps
    @State var steps: [StepEntry] = []
    @State var startStepId: Int = 1

    // Schedules
    @State var schedules: [ScheduleEntry] = []

    // Notifications
    @State var notifyOperator = ""
    @State var notifyLevel: NotifyLevelChoice = .none

    @State var errorMessage: String?
    @State var isCreating = false

    @State var selectedTab = 0

    var isFormValid: Bool {
        !jobName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label("General", systemImage: "info.circle") }
                    .tag(0)
                stepsTab
                    .tabItem { Label("Steps", systemImage: "list.number") }
                    .tag(1)
                schedulesTab
                    .tabItem { Label("Schedules", systemImage: "calendar") }
                    .tag(2)
                notificationsTab
                    .tabItem { Label("Notifications", systemImage: "bell") }
                    .tag(3)
            }

            Divider()

            toolbarView
        }
        .frame(minWidth: 540, minHeight: 440)
        .onAppear { loadCurrentLogin() }
    }

    // MARK: - Toolbar

    var toolbarView: some View {
        HStack {
            if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                Text(error)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                onComplete()
            }
            .keyboardShortcut(.cancelAction)

            Button("Create Job") {
                Task { await createJob() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md2)
    }

    // MARK: - General Tab

    var generalTab: some View {
        Form {
            Section("New Agent Job") {
                TextField("Name", text: $jobName)
                TextField("Description", text: $jobDescription, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Enabled", isOn: $jobEnabled)
                Toggle("Start after creation", isOn: $startAfterCreate)
            }
            Section("Ownership") {
                TextField("Owner", text: $jobOwner, prompt: Text("Current login"))
                TextField("Category", text: $jobCategory, prompt: Text("None"))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
