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
    @State var availableCategories: [String] = []
    @State var showNewCategorySheet = false
    @State var newCategoryName = ""
    @State var newCategoryError: String?

    // Steps
    @State var steps: [StepEntry] = []
    @State var startStepId: Int = 1
    @State var databaseNames: [String] = []

    // Schedules
    @State var schedules: [ScheduleEntry] = []

    // Notifications
    @State var notifyOperator = ""
    @State var notifyLevel: NotifyLevelChoice = .none

    @State var errorMessage: String?
    @State var isCreating = false

    enum Page: String, CaseIterable, Identifiable {
        case general = "General"
        case steps = "Steps"
        case schedules = "Schedules"
        case notifications = "Notifications"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: "info.circle"
            case .steps: "list.number"
            case .schedules: "calendar"
            case .notifications: "bell"
            }
        }
    }

    @State private var selectedPage: Page = .general

    var isFormValid: Bool {
        !jobName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Divider()
                detailPane
            }

            Divider()
            toolbarView
        }
        .frame(minWidth: 620, idealWidth: 660, minHeight: 480, idealHeight: 520)
        .onAppear {
            loadCurrentLogin()
            loadDatabaseNames()
            loadCategories()
        }
        .sheet(isPresented: $showNewCategorySheet) {
            NewAgentCategorySheet(
                categoryName: $newCategoryName,
                errorMessage: $newCategoryError,
                onCreate: {
                    Task { await createCategory() }
                },
                onCancel: { showNewCategorySheet = false }
            )
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(Page.allCases, id: \.self, selection: $selectedPage) { page in
            Label(page.rawValue, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .contentMargins(SpacingTokens.xs)
        .frame(width: 170)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        switch selectedPage {
        case .general: generalTab
        case .steps: stepsTab
        case .schedules: schedulesTab
        case .notifications: notificationsTab
        }
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
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid)
        }
        .padding(SpacingTokens.md2)
    }

    // MARK: - General Page

    var generalTab: some View {
        Form {
            Section("New Agent Job") {
                TextField("Name", text: $jobName, prompt: Text("e.g. Daily Backup"))
                TextField("Description", text: $jobDescription, prompt: Text("What this job does"), axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Enabled", isOn: $jobEnabled)
                Toggle("Start after creation", isOn: $startAfterCreate)
            }
            Section("Ownership") {
                TextField("Owner", text: $jobOwner, prompt: Text("sa"))
                HStack {
                    Picker("Category", selection: $jobCategory) {
                        Text("[Uncategorized (Local)]").tag("")
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    Button {
                        newCategoryName = ""
                        newCategoryError = nil
                        showNewCategorySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Create new category")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Database Loading

    func loadDatabaseNames() {
        Task {
            do {
                let names = try await session.session.listDatabases()
                await MainActor.run { databaseNames = names }
            } catch {
                databaseNames = []
            }
        }
    }
}
