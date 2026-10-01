import SwiftUI

/// A pane's header in the Agent Jobs tab: today's three styles, or one for every pane.
struct LabAJHeader<Trailing: View>: View {
    let title: String
    var count: Int?
    let style: LabAJHeaders
    /// Details was drawn bigger and further in than the other two panes.
    var isDetails = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text(title).font(style == .today && isDetails ? TypographyTokens.prominent.weight(.semibold) : TypographyTokens.headline)
            if style == .unified, let count {
                Text("\(count)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer(minLength: SpacingTokens.xs)
            trailing
        }
        .padding(.horizontal, style == .today && isDetails ? SpacingTokens.md : SpacingTokens.sm)
        .padding(.vertical, style == .today ? (isDetails ? SpacingTokens.sm : SpacingTokens.xxs2) : SpacingTokens.none)
        .frame(height: style == .unified ? SpacingTokens.lg + SpacingTokens.sm : nil)
    }
}

/// The jobs list.
struct LabAJJobsPane: View {
    let look: LabAJLook
    var selected = "DatabaseIntegrityCheck - USER_DATABASES"

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            LabAJHeader(title: "Jobs", count: LabAJJob.samples.count, style: look.headers) {
                if look.headers == .unified {
                    Image(systemName: "plus").foregroundStyle(ColorTokens.Text.secondary)
                    Image(systemName: "play.fill").foregroundStyle(ColorTokens.Text.secondary)
                }
                Image(systemName: "ellipsis.circle").foregroundStyle(ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.standard)
            columnsHeader
            ForEach(Array(LabAJJob.samples.enumerated()), id: \.offset) { index, job in
                row(job, index: index)
            }
            LabAJEmptyFill(isStriped: look.empty == .today, startIndex: LabAJJob.samples.count)
        }
    }

    private var columnsHeader: some View {
        HStack(spacing: SpacingTokens.xs) {
            if look.columns == .today {
                Text("En…").frame(width: SpacingTokens.lg2, alignment: .leading)
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Owner").frame(width: SpacingTokens.xl2, alignment: .leading)
                Text("Category").frame(width: SpacingTokens.xxxl + SpacingTokens.xs, alignment: .leading)
                Text("Status").frame(width: SpacingTokens.xl2 + SpacingTokens.xs, alignment: .leading)
            } else {
                Text("").frame(width: SpacingTokens.md)
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Last run").frame(width: SpacingTokens.xxxl + SpacingTokens.md, alignment: .leading)
                Text("Next run").frame(width: SpacingTokens.xxxl + SpacingTokens.md, alignment: .leading)
            }
        }
        .font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: SpacingTokens.lg)
        .overlay(alignment: .bottom) { Rectangle().fill(ColorTokens.Separator.primary).frame(height: 0.5) }
    }

    private func row(_ job: LabAJJob, index: Int) -> some View {
        let (symbol, tint) = job.symbol
        let dimmed = job.state == .disabled
        return HStack(spacing: SpacingTokens.xs) {
            Image(systemName: symbol).foregroundStyle(tint)
                .frame(width: look.columns == .today ? SpacingTokens.lg2 : SpacingTokens.md, alignment: .leading)
            Text(job.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(dimmed ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            if look.columns == .today {
                Text("sa").frame(width: SpacingTokens.xl2, alignment: .leading).foregroundStyle(ColorTokens.Text.secondary)
                Text(job.category).lineLimit(1).frame(width: SpacingTokens.xxxl + SpacingTokens.xs, alignment: .leading).foregroundStyle(ColorTokens.Text.secondary)
                Text(job.statusWord).frame(width: SpacingTokens.xl2 + SpacingTokens.xs, alignment: .leading)
                    .foregroundStyle(job.state == .running ? ColorTokens.Status.warning : ColorTokens.Text.tertiary)
            } else {
                Text(job.lastRun).lineLimit(1).frame(width: SpacingTokens.xxxl + SpacingTokens.md, alignment: .leading)
                    .foregroundStyle(job.state == .running ? ColorTokens.Status.warning : job.state == .failed ? ColorTokens.Status.error : ColorTokens.Text.secondary)
                Text(job.nextRun).lineLimit(1).frame(width: SpacingTokens.xxxl + SpacingTokens.md, alignment: .leading)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        .font(TypographyTokens.detail)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: SpacingTokens.lg - SpacingTokens.xxxs)
        .background(job.name == selected ? ColorTokens.Sidebar.selectedFill : (look.empty == .today && !index.isMultiple(of: 2) ? ColorTokens.Sidebar.hoverFill : .clear))
    }
}

/// The empty part of a list: today's stripes keep going to the bottom.
struct LabAJEmptyFill: View {
    let isStriped: Bool
    var startIndex = 0
    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            if isStriped {
                ForEach(0..<14, id: \.self) { index in
                    Rectangle().fill((startIndex + index).isMultiple(of: 2) ? Color.clear : ColorTokens.Sidebar.hoverFill)
                        .frame(height: SpacingTokens.lg - SpacingTokens.xxxs)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}

/// Details: the job's sections and the selected section's content (Steps).
struct LabAJDetailsPane: View {
    let look: LabAJLook

    private var sections: [String] {
        ["Properties", "Steps", "Schedules", "Notifications"] + (look.layout == .historyInDetails ? ["History"] : [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            LabAJHeader(title: "Details", style: look.headers, isDetails: true) {
                if look.sections == .header { picker }
            }
            if look.sections != .header {
                picker.frame(maxWidth: .infinity, alignment: look.sections == .today ? .center : .leading)
                    .padding(.horizontal, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
            }
            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
                Text("1").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    HStack(spacing: SpacingTokens.xxs2) {
                        Text("DatabaseIntegrityCheck - USER_DATABASES").font(TypographyTokens.standard).lineLimit(1)
                        Text("TSQL").font(TypographyTokens.label.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.horizontal, SpacingTokens.xxs).background(ColorTokens.Sidebar.hoverFill, in: Capsule())
                        Text("master").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    Text("EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = 'USER_DATABASES'")
                        .font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                }
            }
            .padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs2)
            LabAJEmptyFill(isStriped: look.empty == .today, startIndex: 1)
            HStack {
                Spacer()
                Label("New Step", systemImage: "plus").font(TypographyTokens.detail)
                    .padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.lg - SpacingTokens.xxxs)
                    .glassEffect(.regular, in: .capsule)
            }
            .padding(SpacingTokens.xs)
        }
    }

    private var picker: some View {
        Picker("Section", selection: .constant("Steps")) {
            ForEach(sections, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.segmented).labelsHidden().controlSize(.small).fixedSize()
    }
}

/// History of the selected job.
struct LabAJHistoryPane: View {
    let look: LabAJLook
    private let rows = [("0", "(Job outcome)", "26 Sep 23:00", "00:14:00"), ("1", "DatabaseIntegrityCheck", "26 Sep 23:00", "00:14:00"),
                        ("0", "(Job outcome)", "19 Sep 23:00", "00:13:51"), ("1", "DatabaseIntegrityCheck", "19 Sep 23:00", "00:13:51")]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            LabAJHeader(title: "History", count: look.headers == .unified ? 52 : nil, style: look.headers) { EmptyView() }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: SpacingTokens.sm) {
                    Text(row.0).monospacedDigit().frame(width: SpacingTokens.md)
                    Text(row.1).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                    Text("Succeeded").foregroundStyle(ColorTokens.Status.success)
                    Text(row.2).foregroundStyle(ColorTokens.Text.secondary)
                    Text(row.3).monospacedDigit().foregroundStyle(ColorTokens.Text.secondary)
                }
                .font(TypographyTokens.detail)
                .padding(.horizontal, SpacingTokens.sm)
                .frame(height: SpacingTokens.lg - SpacingTokens.xxxs)
                .background(look.empty == .today && !index.isMultiple(of: 2) ? ColorTokens.Sidebar.hoverFill : .clear)
            }
            Spacer(minLength: 0)
        }
    }
}

/// The whole tab in one of the layouts.
struct LabAJTab: View {
    let look: LabAJLook

    var body: some View {
        Group {
            switch look.layout {
            case .today:
                VStack(spacing: SpacingTokens.xs) {
                    HStack(spacing: SpacingTokens.xs) {
                        LabAJJobsPane(look: look).workspaceCard()
                        LabAJDetailsPane(look: look).workspaceCard()
                    }
                    LabAJHistoryPane(look: look).frame(height: SpacingTokens.xxxl * 2).workspaceCard()
                }
            case .jobsFull:
                HStack(spacing: SpacingTokens.xs) {
                    LabAJJobsPane(look: look).workspaceCard()
                    VStack(spacing: SpacingTokens.xs) {
                        LabAJDetailsPane(look: look).workspaceCard()
                        LabAJHistoryPane(look: look).frame(height: SpacingTokens.xxxl * 2 + SpacingTokens.lg).workspaceCard()
                    }
                }
            case .historyInDetails:
                HStack(spacing: SpacingTokens.xs) {
                    LabAJJobsPane(look: look).workspaceCard()
                    LabAJDetailsPane(look: look).workspaceCard()
                }
            }
        }
        .padding(SpacingTokens.xs)
        .background(ColorTokens.Workspace.canvas)
    }
}
