import SwiftUI

/// Everything across all areas that is waiting for someone, laid out like a mailbox: a list of
/// items grouped by status, and the selected item in a reading pane.
struct LabInboxView: View {
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator

    /// The Inbox's groups, top to bottom: what you judge, what you check in Echo, what the agent has.
    enum Group: String, CaseIterable, Identifiable {
        case judging = "Judging", inEcho = "For you to check in Echo", agent = "With the agent"
        var id: String { rawValue }
        func includes(_ status: LabStatus) -> Bool {
            switch self {
            case .judging: status == .judging
            case .inEcho: status == .inEcho
            case .agent: status == .newFeedback || status == .accepted
            }
        }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", judging = "Judging", inEcho = "For you to check in Echo", agent = "With the agent"
        var id: String { rawValue }
        var group: Group? {
            switch self {
            case .all: nil
            case .judging: .judging
            case .inEcho: .inEcho
            case .agent: .agent
            }
        }
    }

    @AppStorage("lab.inbox.filter") private var filter: Filter = .all
    @AppStorage("lab.inbox.selected") private var selectedID: String?
    @State private var search = ""


    private var items: [LabPage] {
        LabRegistry.pages.filter { page in
            guard let status = store.status(of: page), Group.allCases.contains(where: { $0.includes(status) }),
                  page.section != .test, page.section != .reference else { return false }
            if let wanted = filter.group, !wanted.includes(status) { return false }
            let query = search.trimmingCharacters(in: .whitespaces).lowercased()
            return query.isEmpty || page.title.lowercased().contains(query) || areaTitle(page).lowercased().contains(query)
                || page.summary.lowercased().contains(query)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Inbox").font(TypographyTokens.title2.weight(.bold))
                    Text("\(store.attentionCount) for you · \(store.agentCount) with the agent")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                }
                .padding(SpacingTokens.sm)
                Divider()
                list
            }
            .frame(width: 400)
            Divider()
            reading
        }
        .background(ColorTokens.Workspace.canvas)
        .searchable(text: $search, placement: .toolbar, prompt: "Search the inbox")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: filter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 15, weight: .regular))
                        .frame(width: 22, height: 22)
                        .accessibilityLabel("Filter")
                }
                .menuIndicator(.hidden)
                .help("Show: \(filter.rawValue)")
            }
        }
    }

    private var list: some View {
        List(selection: $selectedID) {
            ForEach(Group.allCases) { turn in
                let group = items.filter { store.status(of: $0).map(turn.includes) ?? false }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { page in
                            row(page, status: store.status(of: page) ?? .judging).tag(page.id)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { navigator.openPage(page.id) }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Text(turn.rawValue).fontWeight(.semibold)
                            Text("\(group.count)").foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .font(TypographyTokens.detail)
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(search.isEmpty ? "All caught up" : "No matches",
                                       systemImage: search.isEmpty ? "tray" : "magnifyingglass",
                                       description: Text(search.isEmpty ? "Nothing is waiting for you or the agent." : "Try a different search."))
            }
        }
        .onAppear { if selectedID == nil || !items.contains(where: { $0.id == selectedID }) { selectedID = items.first?.id } }
    }

    private func row(_ page: LabPage, status: LabStatus) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.symbol).font(.system(size: 11)).foregroundStyle(status.tint).frame(width: 14).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    LabRoundTitle(text: page.title, pageID: page.id)
                    Spacer(minLength: 4)
                    Text(dateText(page)).font(TypographyTokens.detail).foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    Text(areaTitle(page)).font(TypographyTokens.detail).foregroundStyle(.secondary)
                    LabTag(text: "Rev \(store.revision(of: page))", symbol: "arrow.triangle.2.circlepath")
                    if store.revision(of: page) > store.reviewedRevision(of: page) {
                        Text("New since rev \(store.reviewedRevision(of: page))")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(ColorTokens.accent)
                    }
                }
                Text(preview(page)).font(TypographyTokens.detail).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Reading pane

    @ViewBuilder
    private var reading: some View {
        if let id = selectedID, let page = items.first(where: { $0.id == id }) ?? LabRegistry.page(id: id) {
            LabMailPageDetail(page: page)
        } else {
            LabMailEmpty(title: "Select an item", symbol: "tray")
        }
    }

    private func areaTitle(_ page: LabPage) -> String {
        LabAreas.area(id: LabAreas.areaID(ofPage: page.id))?.title ?? "No area yet"
    }

    private func dateText(_ page: LabPage) -> String {
        LabRounds.info(forPage: page.id)?.date.replacingOccurrences(of: " 2026", with: "") ?? ""
    }

    /// What changed since your last review, else your latest comment, else what the page is about.
    private func preview(_ page: LabPage) -> String {
        if let change = store.revisionsSinceReview(of: page).flatMap({ $0.changes.isEmpty ? [$0.summary] : $0.changes }).first, !change.isEmpty {
            return "Since your review: " + change
        }
        return store.comments(for: page).last.map { LabRoundName.stripped($0.text) } ?? page.summary
    }
}

/// An inbox item in the reading pane.
struct LabMailPageDetail: View {
    let page: LabPage
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator

    var body: some View {
        let info = LabRounds.info(forPage: page.id)
        let areaTitle = LabAreas.area(id: LabAreas.areaID(ofPage: page.id))?.title
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text([info?.date, areaTitle].compactMap { $0 }.joined(separator: " · "))
                        .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    LabRoundTitle(text: page.title, pageID: page.id, font: .system(size: 26, weight: .bold), badgeSize: 16)
                    HStack(spacing: 6) {
                        if let status = store.status(of: page) { LabStatusChip(status: status) }
                        LabTag(text: "Rev \(store.revision(of: page))", symbol: "arrow.triangle.2.circlepath")
                        if let areaTitle { LabTag(text: areaTitle, symbol: "square.grid.2x2") }
                    }
                    Button { navigator.openPage(page.id) } label: { Label("Open", systemImage: "arrow.up.right.square") }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true)).padding(.top, 4)
                }
                sinceReview
                if !page.summary.isEmpty {
                    LabReadingCard(title: "What it's about", symbol: "text.alignleft") {
                        Text(page.summary).font(TypographyTokens.prominent).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let info {
                    LabReadingCard(title: "What the round asked", symbol: "questionmark.bubble") {
                        Text(info.asked).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
                        Text(info.outcome).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                feedback
            }
            .padding(SpacingTokens.lg)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    /// What to look for: the revisions since the owner last reviewed this page.
    @ViewBuilder
    private var sinceReview: some View {
        let unseen = store.revisionsSinceReview(of: page)
        if !unseen.isEmpty {
            LabReadingCard(title: "Since your last review · rev \(store.reviewedRevision(of: page)) → rev \(store.revision(of: page))", symbol: "sparkles") {
                ForEach(unseen) { revision in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Revision \(revision.number) · \(revision.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.accent)
                        if !revision.summary.isEmpty {
                            Text(revision.summary).font(TypographyTokens.prominent).fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(revision.changes, id: \.self) { change in
                            Label { Text(change).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "eye") .foregroundStyle(ColorTokens.accent) }
                                .font(TypographyTokens.standard)
                        }
                    }
                }
                HStack {
                    Button { navigator.openPage(page.id) } label: { Label("Open and look", systemImage: "arrow.up.right.square") }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent))
                    Button { store.markReviewed(page) } label: { Label("Mark as reviewed", systemImage: "checkmark") }
                        .buttonStyle(LabPillButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        let comments = store.comments(for: page)
        let history = store.history(for: page)
        if !comments.isEmpty {
            LabReadingCard(title: "Your feedback", symbol: "text.bubble") {
                ForEach(comments.reversed().prefix(4)) { comment in
                    VStack(alignment: .leading, spacing: 2) {
                        if let element = comment.element {
                            Text(element).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(ColorTokens.accent)
                        }
                        Text(LabRoundName.stripped(comment.text)).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
                        Text(comment.date.formatted(date: .abbreviated, time: .shortened))
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if comment.id != comments.reversed().prefix(4).last?.id { Divider() }
                }
            }
        }
        let revisions = store.revisions(of: page)
        if !revisions.isEmpty {
            LabReadingCard(title: "Revisions", symbol: "arrow.triangle.2.circlepath") {
                ForEach(revisions.reversed()) { revision in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Revision \(revision.number) · \(revision.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(TypographyTokens.detail.weight(.semibold))
                        if !revision.summary.isEmpty { Text(revision.summary).font(TypographyTokens.standard) }
                        ForEach(revision.changes, id: \.self) { Text("• " + $0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary) }
                    }
                }
            }
        }
        if !history.isEmpty {
            LabReadingCard(title: "History", symbol: "clock") {
                ForEach(Array(history.enumerated().reversed()), id: \.offset) { _, event in
                    HStack {
                        Text(LabRoundName.stripped(event.text))
                        Spacer()
                        Text(event.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .font(TypographyTokens.detail)
                }
            }
        }
    }
}
