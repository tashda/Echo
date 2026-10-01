import SwiftUI

/// The toolbar's right side and the front tab, reacting to the round's actions: a query run, a
/// backup and a press of Refresh, signalled the way the look says.
struct LabRFScene: View {
    let look: RefreshAndActivityRound.Look
    let values: RoundValues

    enum Phase { case idle, running, done }
    @State private var run: Phase = .idle
    @State private var refresh: Phase = .idle
    @State private var bellBusy = false
    @State private var toast: String?
    @State private var activity: [String] = []
    @State private var showsActivity = false
    @State private var front = 0
    @Environment(\.echoMotion) private var motion

    private var refreshInToolbar: Bool {
        switch look.place {
        case .toolbar: true
        case .toolbarWhenUseful: front == 1
        case .inTabs: false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Picker("Front tab", selection: $front) { Text("Query 1").tag(0); Text("Activity Monitor").tag(1) }
                    .pickerStyle(.segmented).labelsHidden().fixedSize().controlSize(.small)
                Spacer()
                runButton
                LabWKToolbarGroup(symbols: ["sparkles", "exclamationmark.triangle"])
                trailingGroup
            }
            ZStack(alignment: .topTrailing) {
                tabContent
                if let toast {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(TypographyTokens.detail).padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xs)
                        .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.sm))
                        .padding(SpacingTokens.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
        .onChange(of: values["pulse"]) { _, pulse in handle(pulse) }
    }

    private var runButton: some View {
        Group {
            switch run {
            case .idle: Image(systemName: "play.fill").foregroundStyle(ColorTokens.Text.primary)
            case .running: Image(systemName: "stop.fill").foregroundStyle(ColorTokens.Text.onFill)
            case .done: Image(systemName: "checkmark").foregroundStyle(ColorTokens.Status.success)
            }
        }
        .font(TypographyTokens.standard.weight(.semibold))
        .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2 - SpacingTokens.xxxs)
        .glassEffect(run == .running ? .regular.tint(ColorTokens.Status.error) : .regular, in: .capsule)
    }

    private var trailingGroup: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "square.grid.2x2").frame(width: SpacingTokens.md2)
            if look.signal == .activity {
                activityButton
            } else if refreshInToolbar {
                refreshIcon(refresh).frame(width: SpacingTokens.md2)
            }
            ZStack {
                Image(systemName: "bell")
                if bellBusy { ProgressView().controlSize(.mini).offset(x: SpacingTokens.xxs2, y: -SpacingTokens.xxs2) }
            }
            .frame(width: SpacingTokens.md2)
            Image(systemName: "sidebar.right").frame(width: SpacingTokens.md2)
        }
        .font(TypographyTokens.standard)
        .padding(.horizontal, SpacingTokens.xs2)
        .frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
        .glassEffect(.regular, in: .capsule)
    }

    private var activityButton: some View {
        Button { showsActivity.toggle() } label: {
            Group {
                if refresh == .running || bellBusy { ProgressView().controlSize(.small) }
                else { Image(systemName: "waveform.path.ecg") }
            }
            .frame(width: SpacingTokens.md2)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsActivity) {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Activity on dkloosql10-p").font(TypographyTokens.headline)
                if activity.isEmpty { Text("Nothing has run yet.").foregroundStyle(ColorTokens.Text.secondary) }
                ForEach(activity, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill").font(TypographyTokens.standard)
                }
            }
            .padding(SpacingTokens.md).frame(width: 280, alignment: .leading)
        }
    }

    @ViewBuilder
    private func refreshIcon(_ phase: Phase) -> some View {
        switch phase {
        case .idle: Image(systemName: "arrow.clockwise")
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark").foregroundStyle(ColorTokens.Status.success)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if front == 0 {
            LabWKEditor(lines: ["select *", "from dbo.aml_checkpoint"]).frame(height: SpacingTokens.xxxl * 2).workspaceCard()
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack {
                    Text("Activity Monitor").font(TypographyTokens.headline)
                    Text("Updated 5 sec ago").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                    if look.place == .inTabs || look.signal == .activity {
                        refreshIcon(refresh).font(TypographyTokens.standard)
                            .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg)
                            .glassEffect(.regular, in: .capsule)
                    }
                }
                Text("CPU 12% · Waiting 179 · I/O 2 MB/s").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            .padding(SpacingTokens.sm)
            .frame(maxWidth: .infinity, minHeight: SpacingTokens.xxxl * 2, alignment: .topLeading)
            .workspaceCard()
        }
    }

    private func handle(_ pulse: String) {
        let kind = pulse.split(separator: "|").first.map(String.init) ?? ""
        let mirrorsEverything = look.signal == .today || look.signal == .notQueries
        Task {
            switch kind {
            case "query":
                withAnimation(motion.standard) { run = .running; if look.signal == .today { refresh = .running } }
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(motion.standard) { run = .done; if look.signal == .today { refresh = .done } }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(motion.standard) { run = .idle; if look.signal == .today { refresh = .idle } }
            case "backup":
                withAnimation(motion.standard) {
                    if mirrorsEverything || look.signal == .activity { refresh = .running } else { bellBusy = true }
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation(motion.standard) {
                    if mirrorsEverything { refresh = .done } else { refresh = .idle }
                    bellBusy = false
                    activity.insert("Backup of ccsLDK10 · 2 s", at: 0)
                    if look.signal == .ownOnly || look.signal == .activity { toast = "Backup of ccsLDK10 finished" }
                }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(motion.standard) { refresh = .idle; toast = nil }
            default:
                withAnimation(motion.standard) { refresh = .running }
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(motion.standard) { refresh = .done }
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(motion.standard) { refresh = .idle }
            }
        }
    }
}
