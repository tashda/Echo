import SwiftUI

/// A tool tab's header and toolbar row, drawn from a look. `running` shows the primary action's
/// running state (Tracing).
struct LabTTHeaderView: View {
    let tool: LabTTTool
    let look: LabTTLook
    var running = true
    @State private var page = ""
    @State private var query = ""
    @State private var searchOpen = false

    var body: some View {
        switch look.header {
        case .today, .twoRows:
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.sm) {
                    title
                    Spacer()
                    if look.header == .twoRows { primaryButton; statusView }
                }
                .frame(height: SpacingTokens.xl2)
                HStack(spacing: SpacingTokens.sm) {
                    if look.header == .today { primaryButton }
                    pages
                    pickerView
                    if look.header == .today { secondaryButtons }
                    Spacer()
                    if look.header == .today { statusView }
                    searchView
                    if look.header == .twoRows { secondaryButtons }
                }
                .frame(height: SpacingTokens.xl)
            }
        case .oneRow:
            HStack(spacing: SpacingTokens.sm) {
                title
                pages
                Spacer()
                pickerView
                searchView
                secondaryButtons
                primaryButton
            }
            .frame(height: SpacingTokens.xl2)
        case .glassBar:
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                title.frame(height: SpacingTokens.xl2)
                HStack(spacing: SpacingTokens.sm) {
                    pages
                    pickerView
                    Spacer()
                    searchView
                    secondaryButtons
                    primaryButton
                }
                .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxs)
                .glassEffect(.regular, in: .capsule)
            }
        case .oneLine, .slimLine, .glassLine, .controlsOnly:
            oneLineHeader
        case .windowToolbar:
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                HStack(spacing: SpacingTokens.xs) {
                    Spacer()
                    Text("Window toolbar").font(TypographyTokens.label).foregroundStyle(ColorTokens.Text.tertiary)
                    HStack(spacing: SpacingTokens.sm) { pickerView; secondaryButtons; primaryButton }
                        .padding(.horizontal, SpacingTokens.xs2).frame(height: SpacingTokens.lg2)
                        .glassEffect(.regular, in: .capsule)
                }
                title.frame(height: SpacingTokens.xl2)
                pages
            }
        }
    }

    var title: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: tool.symbol).font(TypographyTokens.prominent.weight(.semibold)).foregroundStyle(tool.tint)
                .frame(width: SpacingTokens.lg + SpacingTokens.xxs, height: SpacingTokens.lg + SpacingTokens.xxs)
                .background(tool.tint.opacity(0.12), in: .rect(cornerRadius: SpacingTokens.xxs3, style: .continuous))
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                Text(tool.name).font(TypographyTokens.standard.weight(.semibold))
                Text(tool.subtitle).font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    @ViewBuilder
    var pages: some View {
        if !tool.pages.isEmpty {
            Picker("Page", selection: Binding(get: { page.isEmpty ? tool.pages[0] : page }, set: { page = $0 })) {
                ForEach(tool.pages, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize().controlSize(look.header == .today ? .small : .regular)
        }
    }

    @ViewBuilder
    var primaryButton: some View {
        if let primary = tool.primary, look.primaryInHeader {
            let isStop = running && look.status == .inButton && primary.title == "Start Trace"
            let title = isStop ? "Stop Trace" : primary.title
            let symbol = isStop ? "stop.fill" : primary.symbol
            switch look.primary {
            case .today:
                Button { } label: { Label(running && primary.title == "Start Trace" ? "Stop Trace" : title, systemImage: symbol) }
                    .buttonStyle(.bordered).controlSize(.small).tint(running ? ColorTokens.Status.error : ColorTokens.accent)
            case .glass:
                HStack(spacing: SpacingTokens.xxs2) {
                    if isStop { Circle().fill(ColorTokens.Status.error).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2) }
                    else { Image(systemName: symbol).foregroundStyle(ColorTokens.accent) }
                    Text(title).foregroundStyle(ColorTokens.Text.secondary)
                }
                .font(TypographyTokens.standard.weight(.medium))
                .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                .glassEffect(.regular.interactive(), in: .capsule)
            case .prominent:
                Button { } label: { Label(title, systemImage: symbol) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(isStop ? ColorTokens.Status.error : ColorTokens.accent)
            case .text:
                Button { } label: { Label(title, systemImage: symbol) }
                    .buttonStyle(.plain).foregroundStyle(isStop ? ColorTokens.Status.error : ColorTokens.accent).font(TypographyTokens.standard.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    var secondaryButtons: some View {
        if !tool.secondary.isEmpty {
            switch look.secondary {
            case .today:
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(tool.secondary, id: \.symbol) { item in Image(systemName: item.symbol).help(item.help) }
                }
                .foregroundStyle(ColorTokens.Text.secondary)
            case .circles:
                HStack(spacing: SpacingTokens.xxs2) {
                    ForEach(tool.secondary, id: \.symbol) { item in
                        Image(systemName: item.symbol).frame(width: SpacingTokens.lg2 - SpacingTokens.xxxs, height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                            .glassEffect(.regular.interactive(), in: Circle()).help(item.help)
                    }
                }
            case .group:
                HStack(spacing: SpacingTokens.sm) {
                    ForEach(tool.secondary, id: \.symbol) { item in Image(systemName: item.symbol).help(item.help) }
                }
                .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                .glassEffect(.regular, in: .capsule)
            }
        }
    }

    @ViewBuilder
    var pickerView: some View {
        if let picker = tool.picker {
            switch look.picker {
            case .today:
                HStack(spacing: SpacingTokens.xs) {
                    Text(picker.label).font(TypographyTokens.standard)
                    Picker(picker.label, selection: .constant(picker.value)) { Text(picker.value).tag(picker.value) }
                        .labelsHidden().pickerStyle(.menu).controlSize(.small).fixedSize()
                }
            case .pill:
                HStack(spacing: SpacingTokens.xxs2) {
                    Image(systemName: picker.label == "Database" ? "cylinder" : "timer").foregroundStyle(ColorTokens.Text.secondary)
                    Text(picker.value)
                    Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                }
                .font(TypographyTokens.standard)
                .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                .glassEffect(.regular.interactive(), in: .capsule)
            case .chip:
                Text("\(picker.label): \(picker.value)").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, SpacingTokens.xs2).frame(height: SpacingTokens.lg)
                    .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
            }
        }
    }

    @ViewBuilder
    var statusView: some View {
        if running, let status = tool.status {
            switch look.status {
            case .today:
                Label(status, systemImage: "record.circle").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Status.success)
            case .inButton:
                EmptyView()
            case .pill:
                HStack(spacing: SpacingTokens.xxs) {
                    Circle().fill(ColorTokens.Status.error).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                    Text("\(status) · 0:42").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
                }
                .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding).frame(height: LayoutTokens.Footer.chipHeight)
                .glassEffect(.regular, in: .capsule)
            }
        }
    }

    @ViewBuilder
    var searchView: some View {
        if let prompt = tool.searchPrompt {
            switch look.search {
            case .none: EmptyView()
            case .capsule:
                HStack(spacing: SpacingTokens.xxs2) {
                    Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
                    TextField(prompt, text: $query, prompt: Text(prompt)).textFieldStyle(.plain).frame(width: 140)
                }
                .font(TypographyTokens.standard)
                .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                .glassEffect(.regular, in: .capsule)
            case .expanding:
                HStack(spacing: SpacingTokens.xxs2) {
                    Image(systemName: "magnifyingglass").foregroundStyle(ColorTokens.Text.secondary)
                    if searchOpen { TextField(prompt, text: $query, prompt: Text(prompt)).textFieldStyle(.plain).frame(width: 140) }
                }
                .padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                .glassEffect(.regular.interactive(), in: .capsule)
                .onTapGesture { withAnimation { searchOpen.toggle() } }
            }
        }
    }
}

/// A tool tab: the header on the canvas over a pane card with sample rows.
struct LabTTTab: View {
    let tool: LabTTTool
    let look: LabTTLook
    var running = true

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if look.header.isOneLine {
                LabTPStrip(tabs: [.query2, tool.stripTab], activeID: tool.stripTab.id, style: .today, refine: .accepted)
            }
            LabTTHeaderView(tool: tool, look: look, running: running)
            VStack(spacing: SpacingTokens.none) {
                ForEach(0..<6, id: \.self) { row in
                    HStack {
                        Text(["15:34:51.204", "15:34:51.212", "15:34:51.230", "15:34:52.004", "15:34:52.118", "15:34:52.901"][row]).monospacedDigit()
                        Text(["SQL:BatchCompleted", "RPC:Completed", "SQL:BatchStarting", "SQL:BatchCompleted", "Lock:Timeout", "RPC:Completed"][row])
                            .frame(width: 160, alignment: .leading)
                        Text(["ESB_INTEGRATION", "ccsLDK10", "master", "ESB_INTEGRATION", "ccsLDK10", "DBA"][row]).foregroundStyle(ColorTokens.Text.secondary)
                        Spacer()
                    }
                    .font(TypographyTokens.detail)
                    .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, SpacingTokens.xs)
            .workspaceCard()
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }
}
