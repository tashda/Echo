import SwiftUI
import AppKit
import HatchCore

// Project settings (decisions L1, L2, M): a form that writes .hatch/project.json into the app repo and keeps the database in step.

struct HXRepoDraft: Identifiable {
    let id = UUID()
    var role: RepoRole
    var remote: String
    var branch: String
    var localPath: String
    var build: String
    var plans: String
}

struct HXAreaDraft: Identifiable {
    let id = UUID()
    var name: String
    var globs: String
    var prefix: String
}

struct HXDocDraft: Identifiable {
    let id = UUID()
    var path: String
}

func hxRoleName(_ role: RepoRole) -> String {
    switch role {
    case .app: return "App"
    case .designSystem: return "Design system"
    case .specimens: return "Specimens"
    case .tickets: return "Tickets"
    }
}

struct ProjectView: View {
    @EnvironmentObject var state: AppState
    @State private var showAdd = false

    var body: some View {
        Group {
            if let project = state.hxProject {
                ProjectForm(project: project)
                    .id(project.id)
            } else {
                VStack(spacing: 12) {
                    HXEmpty(symbol: "gearshape", title: "No project yet", detail: "Add your first project to link its repositories.")
                    Button("Add project") { showAdd = true }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddProjectSheet() }
    }
}

struct ProjectForm: View {
    @EnvironmentObject var state: AppState
    let project: Project

    @State private var name = ""
    @State private var ticketsRepo = ""
    @State private var maxAgents = 3
    @State private var integrationBranch = "hatch"
    @State private var threshold = 8
    @State private var repos: [HXRepoDraft] = []
    @State private var areas: [HXAreaDraft] = []
    @State private var docs: [HXDocDraft] = []
    @State private var message = ""
    @State private var showAdd = false
    @State private var loaded = false

    private var appLocalPath: String? {
        let path = repos.first { $0.role == .app }?.localPath ?? ""
        return path.isEmpty ? nil : path
    }

    private var configURL: URL? {
        guard let path = appLocalPath else { return nil }
        return URL(fileURLWithPath: path).appendingPathComponent(".hatch/project.json")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topRow
                generalSection
                reposSection
                areasSection
                docsSection
                saveRow
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { if !loaded { load(); loaded = true } }
        .sheet(isPresented: $showAdd) { AddProjectSheet() }
    }

    // MARK: Sections

    private var topRow: some View {
        HStack(alignment: .top) {
            HXHeader(title: "Project: \(project.name)", subtitle: configURL.map { "Config in repo: \($0.path)" } ?? "Config in repo: .hatch/project.json (set the app repo's local path to write it)")
            Spacer()
            Button("Add project...") { showAdd = true }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General").font(.headline)
            HXCard {
                VStack(alignment: .leading, spacing: 8) {
                    labeled("Name") { TextField("Name", text: $name).textFieldStyle(.roundedBorder) }
                    labeled("Tickets repo") { TextField("owner/hatch-tickets", text: $ticketsRepo).textFieldStyle(.roundedBorder) }
                    labeled("Integration branch") { TextField("hatch", text: $integrationBranch).textFieldStyle(.roundedBorder) }
                    labeled("Max agents") { Stepper(value: $maxAgents, in: 1...12) { Text("\(maxAgents)") } }
                    labeled("Plan approval above") { Stepper(value: $threshold, in: 1...100) { Text("\(threshold) files") } }
                    if state.hxSetting("max_agents") != nil {
                        Text("A value set in Settings overrides Max agents.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).frame(width: 150, alignment: .leading).foregroundStyle(.secondary)
            content()
        }
    }

    private var reposSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Repositories").font(.headline)
                Spacer()
                Button { addRepo() } label: { Label("Add repository", systemImage: "plus") }
            }
            HXCard {
                VStack(alignment: .leading, spacing: 12) {
                    if repos.isEmpty { Text("No repositories yet.").foregroundStyle(.secondary) }
                    ForEach($repos) { $repo in repoRow($repo) }
                }
            }
        }
    }

    private func repoRow(_ repo: Binding<HXRepoDraft>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("Role", selection: repo.role) {
                    ForEach(RepoRole.allCases, id: \.self) { r in Text(hxRoleName(r)).tag(r) }
                }
                .labelsHidden()
                .frame(width: 140)
                TextField("owner/repo", text: repo.remote).textFieldStyle(.roundedBorder)
                TextField("Branch", text: repo.branch).textFieldStyle(.roundedBorder).frame(width: 90)
                Button { removeRepo(repo.wrappedValue.id) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
            }
            HStack {
                TextField("Local path", text: repo.localPath).textFieldStyle(.roundedBorder)
                Button("Choose...") { chooseFolder(repo) }
            }
            HStack {
                TextField("Build command", text: repo.build).textFieldStyle(.roundedBorder)
                TextField("Test plans (comma separated)", text: repo.plans).textFieldStyle(.roundedBorder)
            }
            Divider()
        }
    }

    private var areasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Areas").font(.headline)
                Spacer()
                Button("Re-scan areas") { rescan() }
                    .disabled(appLocalPath == nil)
                    .help(appLocalPath == nil ? "Set the app repository's local path first." : "Look for new folders and add them as areas.")
                Button { areas.append(HXAreaDraft(name: "", globs: "", prefix: "")) } label: { Label("Add area", systemImage: "plus") }
            }
            HXCard {
                VStack(alignment: .leading, spacing: 8) {
                    if areas.isEmpty { Text("No areas yet. An area index saves the most tokens per ticket.").foregroundStyle(.secondary) }
                    ForEach($areas) { $area in areaRow($area) }
                }
            }
        }
    }

    private func areaRow(_ area: Binding<HXAreaDraft>) -> some View {
        HStack {
            TextField("Name", text: area.name).textFieldStyle(.roundedBorder).frame(width: 150)
            TextField("Globs (comma separated)", text: area.globs).textFieldStyle(.roundedBorder)
            TextField("Spec prefix", text: area.prefix).textFieldStyle(.roundedBorder).frame(width: 90)
            Button { areas.removeAll { $0.id == area.wrappedValue.id } } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
        }
    }

    private var docsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Docs for agents").font(.headline)
                Spacer()
                Button { docs.append(HXDocDraft(path: "")) } label: { Label("Add doc", systemImage: "plus") }
            }
            HXCard {
                VStack(alignment: .leading, spacing: 6) {
                    if docs.isEmpty { Text("No docs listed.").foregroundStyle(.secondary) }
                    ForEach($docs) { $doc in
                        HStack {
                            TextField("CLAUDE.md", text: $doc.path).textFieldStyle(.roundedBorder)
                            Button { docs.removeAll { $0.id == doc.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }

    private var saveRow: some View {
        HStack {
            Button("Save") { save() }.buttonStyle(.borderedProminent)
            Button("Revert") { load() }
            if !message.isEmpty { Text(message).font(.callout).foregroundStyle(.secondary) }
        }
    }

    // MARK: Loading and saving

    private func load() {
        let config = project.config
        name = project.name
        ticketsRepo = config?.ticketsRepo ?? ""
        maxAgents = config?.maxAgents ?? 3
        integrationBranch = config?.integrationBranch ?? "hatch"
        threshold = config?.planApprovalFileThreshold ?? 8
        var list: [RepoConfig] = config?.repos ?? []
        if list.isEmpty {
            let rows = (try? state.store.repos(projectId: project.id)) ?? []
            list = rows.map { RepoConfig(role: $0.role, remote: $0.remote, branch: $0.defaultBranch, localPath: $0.localPath, buildCommand: $0.buildCommand, testPlans: $0.testPlans) }
        }
        repos = list.map { r in
            HXRepoDraft(role: r.role, remote: r.remote, branch: r.branch, localPath: r.localPath ?? "",
                        build: r.buildCommand ?? "", plans: (r.testPlans ?? []).joined(separator: ", "))
        }
        areas = (config?.areas ?? []).map { a in
            HXAreaDraft(name: a.name, globs: a.paths.joined(separator: ", "), prefix: a.specPrefix ?? "")
        }
        docs = (config?.docs ?? []).map { HXDocDraft(path: $0) }
        message = ""
    }

    private func splitList(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func makeConfig() -> ProjectConfig {
        let repoConfigs: [RepoConfig] = repos.filter { !$0.remote.isEmpty }.map { r in
            RepoConfig(role: r.role, remote: r.remote, branch: r.branch.isEmpty ? "main" : r.branch,
                       localPath: r.localPath.isEmpty ? nil : r.localPath,
                       buildCommand: r.build.isEmpty ? nil : r.build,
                       testPlans: splitList(r.plans))
        }
        let areaConfigs: [AreaConfig] = areas.filter { !$0.name.isEmpty }.map { a in
            AreaConfig(name: a.name, paths: splitList(a.globs), specPrefix: a.prefix.isEmpty ? nil : a.prefix)
        }
        return ProjectConfig(name: name, ticketsRepo: ticketsRepo, repos: repoConfigs, areas: areaConfigs,
                             docs: docs.map { $0.path }.filter { !$0.isEmpty }, maxAgents: maxAgents,
                             integrationBranch: integrationBranch.isEmpty ? "hatch" : integrationBranch,
                             planApprovalFileThreshold: threshold)
    }

    private func save() {
        let config = makeConfig()
        let url = configURL
        let key = project.key
        let projectName = name.isEmpty ? project.name : name
        let result: Bool? = state.perform("Save project") {
            try state.store.upsertProject(key: key, name: projectName, config: config)
            if let url { try config.save(to: url) }
            return url != nil
        }
        if let wrote = result {
            message = wrote ? "Saved, and written to .hatch/project.json." : "Saved. Set the app repo's local path to also write .hatch/project.json."
        }
    }

    private func addRepo() {
        let used = Set(repos.map { $0.role })
        let role = RepoRole.allCases.first { !used.contains($0) } ?? .app
        repos.append(HXRepoDraft(role: role, remote: "", branch: "main", localPath: "", build: "", plans: ""))
    }

    private func removeRepo(_ id: UUID) { repos.removeAll { $0.id == id } }

    private func chooseFolder(_ repo: Binding<HXRepoDraft>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { repo.wrappedValue.localPath = url.path }
    }

    private func rescan() {
        guard let path = appLocalPath else { return }
        let found = HXAreasAdapter.suggestAreas(repoPath: path)
        let existing = Set(areas.map { $0.name.lowercased() })
        var added = 0
        for a in found where !existing.contains(a.name.lowercased()) {
            areas.append(HXAreaDraft(name: a.name, globs: a.paths.joined(separator: ", "), prefix: a.specPrefix ?? ""))
            added += 1
        }
        message = added == 0 ? "No new areas found." : "Added \(added) area(s). Review them, then Save."
    }
}

/// The add-project flow: a key, a name, the tickets repo and the app repo.
struct AddProjectSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var key = ""
    @State private var name = ""
    @State private var ticketsRepo = ""
    @State private var appRemote = ""
    @State private var appPath = ""
    @State private var branch = "dev"

    private var canAdd: Bool {
        !key.trimmingCharacters(in: .whitespaces).isEmpty && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add project").font(.title3.weight(.semibold))
            TextField("Key (for labels, such as echo)", text: $key).textFieldStyle(.roundedBorder)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            TextField("Tickets repo (owner/hatch-tickets)", text: $ticketsRepo).textFieldStyle(.roundedBorder)
            TextField("App repo (owner/app)", text: $appRemote).textFieldStyle(.roundedBorder)
            HStack {
                TextField("App repo local path", text: $appPath).textFieldStyle(.roundedBorder)
                Button("Choose...") { choose() }
            }
            TextField("App base branch", text: $branch).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { add() }.buttonStyle(.borderedProminent).disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url { appPath = url.path }
    }

    private func add() {
        let cleanKey = key.trimmingCharacters(in: .whitespaces).lowercased()
        var repos: [RepoConfig] = []
        if !appRemote.isEmpty {
            repos.append(RepoConfig(role: .app, remote: appRemote, branch: branch.isEmpty ? "dev" : branch, localPath: appPath.isEmpty ? nil : appPath))
        }
        if !ticketsRepo.isEmpty {
            repos.append(RepoConfig(role: .tickets, remote: ticketsRepo, branch: "main"))
        }
        let config = ProjectConfig(name: name, ticketsRepo: ticketsRepo, repos: repos)
        let created: Project? = state.perform("Add project") {
            try state.store.upsertProject(key: cleanKey, name: name, config: config)
        }
        if let created {
            state.selectedProjectKey = created.key
            state.route = .projects
            dismiss()
        }
    }
}
