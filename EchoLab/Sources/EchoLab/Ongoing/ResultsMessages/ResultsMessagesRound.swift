import SwiftUI

/// Round 41.4 · Results: the Messages panel. Echo today (ExecutionConsoleView, +Messages): a
/// toolbar on a grey strip (Messages, a count badge, an All/Errors/Warnings segmented control, a
/// trash and a copy button; in the owner's screenshot the trash sits on top of "Warnings"); rows with
/// a symbol, a category (Query Execution, Server Response, Performance), the time, "+104 ms" since the
/// previous message, then the message. Errors are pink rows with red text, the header in red
/// monospaced type; a Performance row prints developer metrics ("dispatch 55 ms, rss 367,7 MB…").
@MainActor
enum ResultsMessagesRound {
    enum Layout: String, CaseIterable {
        case today = "ML0 · Columns: symbol, category, time, delta, message (today)"
        case statements = "ML1 · Grouped by statement: the SQL's first line, then what it said"
        case console = "ML2 · Plain text, as SSMS's Messages tab"
        case quiet = "ML3 · One line each: symbol and message; time on hover"

        var summary: String {
            switch self {
            case .today: "Five columns for four messages; the category repeats what the symbol says."
            case .statements: "Each statement you ran is a heading (line 7: select * from ba_tbl), its messages under it. Long scripts read like a report."
            case .console: "Selectable monospaced text, exactly what the server sent; nothing to click."
            case .quiet: "Least to read; errors still stand out by their symbol and weight."
            }
        }
    }

    enum Errors: String, CaseIterable {
        case pink = "EE0 · A pink row and red text (today)"
        case symbol = "EE1 · Red symbol and a semibold message; no fill"
        case bar = "EE2 · A red bar at the row's leading edge"
    }

    enum Metrics: String, CaseIterable {
        case shown = "DM0 · A Performance row in every run (today)"
        case timePopover = "DM1 · Gone from Messages; in the time pill's popover (41.5)"
        case setting = "DM2 · Only with Settings › Advanced › Show Execution Metrics"
    }

    enum Toolbar: String, CaseIterable {
        case today = "MT0 · Grey strip with All/Errors/Warnings, trash and copy (today)"
        case counts = "MT1 · No strip: '1 error · 2 messages' as filters, copy and clear in a ⋯ menu"
    }

    static let spec = RoundSpec(
        controls: [
            .of("layout", "Layout", Layout.self, default: .statements,
                question: "Compare the layouts with the failed query, then imagine a 40-statement script.",
                recommend: .statements,
                why: "What you want from Messages is 'which statement said what'; grouping by statement answers it and makes Line 1 meaningful (it's relative to the statement). Category and delta columns are developer detail.",
                summary: \.summary),
            .of("errors", "Errors", Errors.self, default: .symbol,
                question: "How should an error row stand out?",
                recommend: .symbol,
                why: "A red symbol and semibold text are enough among four rows; pink fills and red monospaced text are the distraction you mentioned, and red text is harder to read than black."),
            .of("metrics", "Execution metrics", Metrics.self, default: .timePopover,
                question: "Where should 'dispatch 55 ms, cpu 24 ms, rss 367,7 MB…' go?",
                recommend: .timePopover,
                why: "They describe the run's time and memory, which is what the time pill is about; in Messages they're noise between the server's own messages."),
            .of("toolbar", "Top", Toolbar.self, default: .counts,
                question: "Compare the panel's top.",
                recommend: .counts,
                why: "Counts that filter when clicked say what's there and do the job of the segmented control; the grey strip goes, and so does the trash overlapping Warnings."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "As in your screenshot.", isEchoToday: true, isWide: true, designWidth: 860, designHeight: 330) { _ in
                LabMSPanel(layout: .today, errors: .pink, metrics: .shown, toolbar: .today)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.", isWide: true, designWidth: 860, designHeight: 330) { values in
                LabMSPanel(layout: Layout(rawValue: values["layout"]) ?? .statements, errors: Errors(rawValue: values["errors"]) ?? .symbol,
                           metrics: Metrics(rawValue: values["metrics"]) ?? .timePopover, toolbar: Toolbar(rawValue: values["toolbar"]) ?? .counts)
            },
        ],
        questions: [
            .init(id: "echoMessages", title: "Echo's own lines",
                  question: "'Query execution started' and 'Query execution failed' come from Echo, not the server. Keep them?",
                  choices: [.init(id: "drop", name: "EM0 · Drop them: the footer's status says it"), .init(id: "keep", name: "EM1 · Keep them")],
                  recommended: "drop",
                  why: "Messages should be what the server said; Echo's own state is already in the status pill and the Run button."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["layout": Layout.statements.rawValue, "errors": Errors.symbol.rawValue,
                                                                             "metrics": Metrics.timePopover.rawValue, "toolbar": Toolbar.counts.rawValue], isRecommended: true)]
    )
}

private struct LabMSPanel: View {
    let layout: ResultsMessagesRound.Layout
    let errors: ResultsMessagesRound.Errors
    let metrics: ResultsMessagesRound.Metrics
    let toolbar: ResultsMessagesRound.Toolbar

    private struct Message: Hashable { let symbol: String; let tint: Color; let category: String; let time: String; let delta: String; let text: String; let header: String?; let isError: Bool; let isEcho: Bool }

    private var messages: [Message] {
        var list: [Message] = [
            .init(symbol: "info.circle", tint: ColorTokens.Status.info, category: "Query Execution", time: "15:34:51", delta: "", text: "Query execution started", header: nil, isError: false, isEcho: true),
            .init(symbol: "xmark.circle", tint: ColorTokens.Status.error, category: "Server Response", time: "15:34:51", delta: "+104 ms",
                  text: "The conversion of the varchar value '2610000125260' overflowed an int column.", header: "Msg 248, Level 16, State 1, Line 1", isError: true, isEcho: false),
            .init(symbol: "xmark.circle", tint: ColorTokens.Status.error, category: "Query Execution", time: "15:34:51", delta: "+0 ms", text: "Query execution failed", header: nil, isError: true, isEcho: true),
        ]
        if metrics == .shown {
            list.append(.init(symbol: "ladybug", tint: ColorTokens.Text.secondary, category: "Performance", time: "15:34:51", delta: "+0 ms",
                              text: "Execution metrics: dispatch 55 ms, finished 104 ms, cpu 24 ms, rss 367,7 MB, rows 0, batches 0, est-mem 65 KB, cancelled true", header: nil, isError: false, isEcho: true))
        }
        return layout == .today ? list : list.filter { !$0.isEcho }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            top
            content
            Spacer(minLength: 0)
            LabWKFooter(server: "dkloosql10-p · ccsLDK10", showsMessages: true, pills: [.rows("0"), .time("0s"), .status("Error", tint: ColorTokens.Status.error)])
        }
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    @ViewBuilder
    private var top: some View {
        if toolbar == .today {
            HStack(spacing: SpacingTokens.sm) {
                Text("Messages").font(TypographyTokens.standard.weight(.semibold))
                Text("\(messages.count)").font(TypographyTokens.detail).padding(.horizontal, SpacingTokens.xxs2).background(ColorTokens.Sidebar.hoverFill, in: Capsule())
                Spacer()
                ZStack(alignment: .trailing) {
                    Picker("Filter", selection: .constant("All")) { ForEach(["All", "Errors", "Warnings"], id: \.self) { Text($0).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                    Image(systemName: "trash").font(TypographyTokens.detail).padding(.trailing, SpacingTokens.xs)
                }
                Image(systemName: "doc.on.doc").font(TypographyTokens.detail)
            }
            .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs2)
            .background(ColorTokens.Background.secondary)
        } else {
            HStack(spacing: SpacingTokens.sm) {
                Text("1 error").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Status.error)
                Text("1 message").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                Spacer()
                Image(systemName: "ellipsis.circle").foregroundStyle(ColorTokens.Text.secondary)
            }
            .padding(.horizontal, SpacingTokens.md).padding(.top, SpacingTokens.sm).padding(.bottom, SpacingTokens.xxs)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch layout {
        case .today:
            ForEach(messages, id: \.self) { m in
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.md) {
                    Image(systemName: m.symbol).foregroundStyle(m.tint)
                    Text(m.category).font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.Text.secondary).frame(width: 110, alignment: .leading)
                    Text(m.time).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
                    Text(m.delta).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.tertiary).frame(width: 60, alignment: .leading)
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        if let header = m.header { Text(header).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Status.error) }
                        Text(m.text).font(TypographyTokens.detail).foregroundStyle(m.isError ? ColorTokens.Status.error : ColorTokens.Text.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
                .background(m.isError ? ColorTokens.Status.error.opacity(0.06) : .clear)
                Divider()
            }
        case .statements:
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xs) {
                    Text("Line 7").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    Text("select * from ba_tbl where uniqueBagID <> 123456").font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                    Spacer()
                    Text("15:34:51 · 104 ms").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
                }
                ForEach(messages, id: \.self) { row($0).padding(.leading, SpacingTokens.sm) }
            }
            .padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xs)
        case .console:
            Text("Msg 248, Level 16, State 1, Line 7\nThe conversion of the varchar value '2610000125260' overflowed an int column.\n\nCompletion time: 2026-10-01T15:34:51.204+02:00")
                .font(TypographyTokens.detail.monospaced()).textSelection(.enabled)
                .foregroundStyle(errors == .pink ? ColorTokens.Status.error : ColorTokens.Text.primary)
                .padding(SpacingTokens.md)
        case .quiet:
            ForEach(messages, id: \.self) { row($0).padding(.horizontal, SpacingTokens.md).padding(.vertical, SpacingTokens.xxs) }
        }
    }

    private func row(_ m: Message) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xs) {
            if errors == .bar && m.isError { Capsule().fill(ColorTokens.Status.error).frame(width: SpacingTokens.xxxs, height: SpacingTokens.md) }
            Image(systemName: m.isError ? "xmark.octagon.fill" : m.symbol).foregroundStyle(m.tint)
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(m.text).font(TypographyTokens.standard.weight(m.isError && errors != .pink ? .semibold : .regular))
                    .foregroundStyle(m.isError && errors == .pink ? ColorTokens.Status.error : ColorTokens.Text.primary)
                    .textSelection(.enabled)
                if let header = m.header {
                    Text(header.replacingOccurrences(of: ", Line 1", with: "")).font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            Spacer()
        }
        .padding(SpacingTokens.xxs)
        .background(m.isError && errors == .pink ? ColorTokens.Status.error.opacity(0.06) : .clear, in: .rect(cornerRadius: SpacingTokens.xxs2))
    }
}
