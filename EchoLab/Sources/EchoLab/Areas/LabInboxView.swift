import SwiftUI

/// Everything across all areas that is waiting for someone, laid out like a mailbox: a list of
/// items grouped by status, and the selected item in a reading pane.
struct LabInboxView: View {
    @Environment(LabStore.self) private var store
    @Environment(LabNavigator.self) private var navigator

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", newFeedback = "New", judging = "Judging", accepted = "Accepted", inEcho = "In Echo"
        var id: String { rawValue }
        var status: LabStatus? {
            switch self {
            case .all: nil
            case .newFeedback: .newFeedback
            case .judging: .judging
            case .accepted: .accepted
            case .inEcho: .inEcho
            }
        }
    }

    @AppStorage("lab.inbox.filter") private var filter: Filter = .all
    @AppStorage("lab.inbox.selected") private var selectedID: String?
    @State private var search = ""

    private let waiting: [LabStatus] = [.newFeedback, .judging, .accepted, .inEcho]

    private var items: [LabPage] {
        LabRegistry.pages.filter { page in
            guard let status = store.status(of: page), waiting.contains(status),
                  page.section != .test, page.section != .reference else { return false }
            if let wanted = filter.status, status != wanted { return false }
            let query = search.trimmingCharacters(in: .whitespaces).lowercased()
            return query.isEmpty || page.title.lowercased().contains(query) || areaTitle(page).lowercased().contains(query)
                || page.summary.lowercased().contains(query)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                LabMailHeader(title: "Inbox", subtitle: "\(store.attentionCount) waiting", search: $search) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().controlSize(.small)
                }
                Divider()
                list
            }
            .frame(width: 400)
            Divider()
            reading
        }
        .background(ColorTokens.Workspace.canvas)
    }

    private var list: some View {
        List(selection: $selectedID) {
            ForEach(waiting, id: \.self) { status in
                let group = items.filter { store.status(of: $0) == status }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { page in row(page, status: status).tag(page.id) }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: status.symbol).foregroundStyle(status.tint)
                            Text(status.rawValue).fontWeight(.semibold)
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
                                       description: Text(search.isEmpty ? "Nothing is waiting for feedback or for the agent." : "Try a different search."))
            }
        }
        .onAppear { if selectedID == nil || !items.contains(where: { $0.id == selectedID }) { selectedID = items.first?.id } }
    }

    private func row(_ page: LabPage, status: LabStatus) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(status == .newFeedback ? status.tint : .clear).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(page.title).font(TypographyTokens.standard.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(dateText(page)).font(TypographyTokens.detail).foregroundStyle(.secondary)
                }
                Text(areaTitle(page)).font(TypographyTokens.detail).foregroundStyle(.secondary)
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

    /// The latest comment if there is one, otherwise what the page is about.
    private func preview(_ page: LabPage) -> String {
        store.comments(for: page).last?.text ?? page.summary
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
                    Text([info.map { "\($0.label) · \($0.date)" }, areaTitle].compactMap { $0 }.joined(separator: " · "))
                        .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    Text(page.title).font(.system(size: 26, weight: .bold))
                    HStack(spacing: 6) {
                        if let status = store.status(of: page) { LabStatusChip(status: status) }
                        if let areaTitle { LabTag(text: areaTitle, symbol: "square.grid.2x2") }
                    }
                    Button { navigator.openPage(page.id) } label: { Label("Open", systemImage: "arrow.up.right.square") }
                        .buttonStyle(LabPillButtonStyle(tint: ColorTokens.accent, prominent: true)).padding(.top, 4)
                }
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
                        Text(comment.text).font(TypographyTokens.standard).fixedSize(horizontal: false, vertical: true)
                        Text(comment.date.formatted(date: .abbreviated, time: .shortened))
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    if comment.id != comments.reversed().prefix(4).last?.id { Divider() }
                }
            }
        }
        if !history.isEmpty {
            LabReadingCard(title: "History", symbol: "clock") {
                ForEach(Array(history.enumerated().reversed()), id: \.offset) { _, event in
                    HStack {
                        Text(event.text)
                        Spacer()
                        Text(event.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .font(TypographyTokens.detail)
                }
            }
        }
    }
}
