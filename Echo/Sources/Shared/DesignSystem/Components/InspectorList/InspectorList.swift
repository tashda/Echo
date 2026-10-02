import SwiftUI

// The list the inspector's Bookmarks, History and Notifications pages share (round IC, G2): a
// summary line with the page's actions, a search field, sentence-case group headings, and each
// group's rows in one grouped box like Details' sections. A row is two lines; the selected row
// opens in place with its content and small bordered buttons.

// MARK: - Header

/// The page's first line under the strip: a summary ("7 bookmarks in 3 folders") and the page's
/// actions (New Folder, one ⋯ menu). The strip already names the page, so this line doesn't.
struct InspectorPageHeader<Actions: View>: View {
    let summary: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Text(summary)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
            Spacer(minLength: SpacingTokens.xs)
            HStack(spacing: SpacingTokens.xxs) { actions() }
                .buttonStyle(.borderless)
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .labelStyle(.iconOnly)
                .fixedSize()
        }
        .padding(.leading, SpacingTokens.md)
        .padding(.trailing, SpacingTokens.xs)
        .frame(height: LayoutTokens.ToolTab.paneHeaderHeight)
    }
}

// MARK: - Search

/// A real search field: a capsule on the group fill, a magnifier, a clear button while typing,
/// and an optional scope token ("Test Postgres ×") that removes itself when clicked. Esc clears.
struct InspectorSearchField: View {
    @Binding var text: String
    let prompt: String
    var token: String?
    var onRemoveToken: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.xxs1) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
            if let token {
                Button {
                    onRemoveToken?()
                } label: {
                    HStack(spacing: SpacingTokens.xxxs) {
                        Text(token).lineLimit(1)
                        Image(systemName: "xmark").font(TypographyTokens.compact.weight(.semibold))
                    }
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.accent)
                    .padding(.horizontal, SpacingTokens.xxs2)
                    .padding(.vertical, SpacingTokens.micro)
                    .background(ColorTokens.accent.opacity(LayoutTokens.InspectorList.tokenFillOpacity), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Search all servers")
            }
            TextField("Search", text: $text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onKeyPress(.escape) {
                    guard !text.isEmpty else { return .ignored }
                    text = ""
                    return .handled
                }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(ColorTokens.Text.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(TypographyTokens.standard)
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.InspectorList.searchHeight)
        .background(ColorTokens.Workspace.groupFill, in: Capsule())
        .overlay(Capsule().stroke(ColorTokens.accent.opacity(isFocused ? LayoutTokens.InspectorList.focusRingOpacity : 0),
                                  lineWidth: LayoutTokens.InspectorList.focusRingWidth))
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.bottom, SpacingTokens.xxs2)
    }
}

// MARK: - Groups

/// A group's heading: 11pt semibold secondary in sentence case, its count at the right. Folders
/// add a disclosure chevron and fold on a click.
struct InspectorGroupHeading: View {
    let title: String
    var count: Int?
    /// nil: no disclosure (days). Otherwise whether the group is folded.
    var isFolded: Bool?
    var onToggle: (() -> Void)?
    /// Double-click (a folder's rename).
    var onDoubleClick: (() -> Void)?

    @Environment(\.echoMotion) private var motion

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            if let isFolded {
                Image(systemName: "chevron.down")
                    .font(TypographyTokens.compact.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .rotationEffect(.degrees(isFolded ? -90 : 0))
                    .animation(motion.standard, value: isFolded)
            }
            Text(title)
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
            Spacer(minLength: SpacingTokens.xs)
            if let count {
                Text("\(count)")
                    .font(TypographyTokens.detail.monospacedDigit())
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(.leading, LayoutTokens.InspectorList.headingLeading)
        .padding(.trailing, LayoutTokens.InspectorList.headingTrailing)
        .padding(.top, SpacingTokens.xxs)
        .frame(height: LayoutTokens.InspectorList.headingHeight)
        .contentShape(Rectangle())
        .modifier(HeadingTaps(onToggle: onToggle, onDoubleClick: onDoubleClick))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(onToggle == nil ? .isHeader : [.isHeader, .isButton])
        .accessibilityValue(isFolded == true ? "Folded" : "")
    }
}

/// A heading's clicks: a double-click is only waited for when the heading has one.
private struct HeadingTaps: ViewModifier {
    let onToggle: (() -> Void)?
    let onDoubleClick: (() -> Void)?

    func body(content: Content) -> some View {
        if let onDoubleClick {
            content
                .onTapGesture(count: 2, perform: onDoubleClick)
                .onTapGesture { onToggle?() }
        } else {
            content.onTapGesture { onToggle?() }
        }
    }
}

/// A group's rows in one rounded box on the group fill, as Details' sections are.
struct InspectorGroupBox<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: LayoutTokens.FloatingSurface.rowCornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.Workspace.groupFill, in: shape)
            .clipShape(shape)
            .padding(.horizontal, LayoutTokens.InspectorList.boxInset)
            .padding(.bottom, LayoutTokens.InspectorList.boxInset)
    }
}

// MARK: - Rows

/// One row: a 14pt glyph, line one (a name, or a statement on one line) with its trailing time,
/// line two (the server's dot, database, result), and, while selected, the opened part under them.
struct InspectorListRow<Glyph: View, Title: View, Trailing: View, Detail: View, Opened: View>: View {
    let isSelected: Bool
    var showsSeparator: Bool
    let glyph: Glyph
    let title: Title
    let trailing: Trailing
    let detail: Detail
    let opened: Opened

    @State private var isHovering = false

    init(isSelected: Bool,
         showsSeparator: Bool,
         @ViewBuilder glyph: () -> Glyph,
         @ViewBuilder title: () -> Title,
         @ViewBuilder trailing: () -> Trailing,
         @ViewBuilder detail: () -> Detail,
         @ViewBuilder opened: () -> Opened) {
        self.isSelected = isSelected
        self.showsSeparator = showsSeparator
        self.glyph = glyph()
        self.title = title()
        self.trailing = trailing()
        self.detail = detail()
        self.opened = opened()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(alignment: .top, spacing: LayoutTokens.InspectorList.glyphGap) {
                glyph
                    .font(TypographyTokens.standard)
                    .frame(width: LayoutTokens.InspectorList.glyphSlot, height: LayoutTokens.InspectorList.lineOneHeight)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    HStack(spacing: SpacingTokens.xxs2) {
                        title
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        trailing
                            .font(TypographyTokens.detail.monospacedDigit())
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .fixedSize()
                    }
                    .frame(minHeight: LayoutTokens.InspectorList.lineOneHeight)
                    detail
                }
            }
            if isSelected {
                opened
                    .padding(.leading, LayoutTokens.InspectorList.glyphSlot + LayoutTokens.InspectorList.glyphGap)
                    .padding(.top, SpacingTokens.xxs2)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, SpacingTokens.xs)
        .padding(.leading, SpacingTokens.xs2)
        .padding(.trailing, SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? ColorTokens.Sidebar.selectedFill : (isHovering ? ColorTokens.Sidebar.hoverFill : Color.clear))
        .overlay(alignment: .top) {
            if showsSeparator && !isSelected {
                Rectangle()
                    .fill(ColorTokens.Text.primary.opacity(LayoutTokens.InspectorList.separatorOpacity))
                    .frame(height: LayoutTokens.Workspace.cardEdgeWidth)
                    .padding(.leading, LayoutTokens.InspectorList.separatorLeading)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Line two of a row: the server's colour as a dot (hollow while it isn't connected), then text.
struct InspectorRowDetail: View {
    let serverColor: Color
    let isConnected: Bool
    let text: Text

    var body: some View {
        HStack(spacing: SpacingTokens.xxs1) {
            Group {
                if isConnected {
                    Circle().fill(serverColor)
                } else {
                    Circle().strokeBorder(serverColor, lineWidth: LayoutTokens.InspectorList.hollowDotWidth)
                }
            }
            .frame(width: LayoutTokens.InspectorList.dotSize, height: LayoutTokens.InspectorList.dotSize)
            .accessibilityHidden(true)
            text
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Opened part

/// A statement in the opened part: monospaced, coloured with the editor theme's keyword, string,
/// number and comment colours, at most `maxLines` lines with Show All. Selectable.
struct InspectorSQLText: View {
    let sql: String
    var maxLines = LayoutTokens.InspectorList.sqlMaxLines

    @Environment(AppState.self) private var appState
    @State private var showsAll = false

    private var lineCount: Int { sql.split(separator: "\n", omittingEmptySubsequences: false).count }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(InspectorSQLColoring.attributed(sql, tokens: appState.sqlEditorTheme.palette.tokens))
                .font(TypographyTokens.Table.sql)
                .lineSpacing(SpacingTokens.xxxs)
                .lineLimit(showsAll ? nil : maxLines)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if lineCount > maxLines {
                Button(showsAll ? "Show Less" : "Show All \(lineCount) Lines") { showsAll.toggle() }
                    .buttonStyle(.link)
                    .font(TypographyTokens.detail)
            }
        }
    }
}

/// A line of quiet text in the opened part (the server and database, a note, a run's times).
struct InspectorOpenedNote: View {
    let text: String
    var systemImage: String?
    var isError = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs1) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(ColorTokens.Text.secondary)
            }
            Text(text)
                .font(isError ? TypographyTokens.detail.monospaced() : TypographyTokens.detail)
                .foregroundStyle(isError ? ColorTokens.Status.error : ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .font(TypographyTokens.detail)
    }
}

/// The opened part's buttons: small bordered capsules, the main action first.
struct InspectorRowActions<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: SpacingTokens.xxs1) { content() }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, SpacingTokens.xxs)
    }
}

/// The empty state every page uses: a symbol, a title, a line, and an optional button.
struct InspectorEmptyState<Action: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        VStack(spacing: SpacingTokens.xxs) {
            Image(systemName: systemImage)
                .font(TypographyTokens.title2)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .padding(.bottom, SpacingTokens.xxs)
            Text(title)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(message)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.tertiary)
                .multilineTextAlignment(.center)
            action()
                .controlSize(.small)
                .padding(.top, SpacingTokens.xxs)
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension InspectorEmptyState where Action == EmptyView {
    init(systemImage: String, title: String, message: String) {
        self.init(systemImage: systemImage, title: title, message: message) { EmptyView() }
    }
}

// MARK: - Formatting

/// Shared formatting for the inspector's lists, made once instead of per row.
enum InspectorListFormat {
    /// The statement on one line: runs of spaces and line breaks become one space.
    static func oneLine(_ sql: String) -> String {
        sql.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Like Run's timer: "467 ms" under a second, "1.2 s" under a minute (locale decimal), then "1:05".
    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return "\(Int((seconds * 1000).rounded())) ms"
        }
        if seconds < 60 {
            return "\(seconds.formatted(.number.precision(.fractionLength(1)))) s"
        }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// A clock time in the user's locale ("08.59", "8:59 AM").
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// A day group's title: Today, Yesterday, a weekday within the week, then a full date.
    static func dayTitle(_ day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)), day >= weekAgo {
            return day.formatted(.dateTime.weekday(.wide))
        }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// A short date for a bookmark's line: Today, Yesterday, a weekday within the week, then "12 Sep".
    static func shortDay(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// Colours a statement with the editor theme's token colours: a small scanner for strings,
/// comments, numbers and keywords, enough for a read-only preview.
enum InspectorSQLColoring {
    static let keywords: Set<String> = [
        "select", "from", "where", "join", "inner", "left", "right", "full", "outer", "cross", "on", "using",
        "group", "by", "order", "having", "limit", "offset", "top", "distinct", "as", "and", "or", "not", "in",
        "is", "null", "like", "between", "exists", "case", "when", "then", "else", "end", "union", "all",
        "insert", "into", "values", "update", "set", "delete", "merge", "truncate", "create", "alter", "drop",
        "table", "view", "index", "exec", "execute", "call", "with", "returning", "asc", "desc", "begin",
        "commit", "rollback", "declare", "go", "if", "while", "return", "procedure", "function", "trigger",
    ]

    static func attributed(_ sql: String, tokens: SQLEditorPalette.TokenColors) -> AttributedString {
        var result = AttributedString()
        var index = sql.startIndex
        func append(_ text: Substring, _ style: SQLEditorPalette.TokenStyle?) {
            var part = AttributedString(String(text))
            if let style {
                part.foregroundColor = style.color.color
                if style.isBold { part.inlinePresentationIntent = .stronglyEmphasized }
            }
            result += part
        }
        while index < sql.endIndex {
            let character = sql[index]
            if character == "'" {
                var end = sql.index(after: index)
                while end < sql.endIndex {
                    if sql[end] == "'" {
                        let next = sql.index(after: end)
                        if next < sql.endIndex, sql[next] == "'" { end = sql.index(after: next); continue }
                        end = next
                        break
                    }
                    end = sql.index(after: end)
                }
                append(sql[index..<end], tokens.string)
                index = end
            } else if character == "-", sql[index...].hasPrefix("--") {
                let end = sql[index...].firstIndex(of: "\n") ?? sql.endIndex
                append(sql[index..<end], tokens.comment)
                index = end
            } else if character.isLetter || character == "_" {
                var end = index
                while end < sql.endIndex, sql[end].isLetter || sql[end].isNumber || sql[end] == "_" { end = sql.index(after: end) }
                let word = sql[index..<end]
                append(word, keywords.contains(word.lowercased()) ? tokens.keyword : nil)
                index = end
            } else if character.isNumber {
                var end = index
                while end < sql.endIndex, sql[end].isNumber || sql[end] == "." { end = sql.index(after: end) }
                append(sql[index..<end], tokens.number)
                index = end
            } else {
                append(sql[index...index], nil)
                index = sql.index(after: index)
            }
        }
        return result
    }
}

extension LayoutTokens {
    /// The inspector's shared list (round IC, G2).
    enum InspectorList {
        static let searchHeight: CGFloat = SpacingTokens.lg
        static let focusRingWidth: CGFloat = 2
        static let focusRingOpacity: Double = 0.45
        static let tokenFillOpacity: Double = 0.14
        static let headingHeight: CGFloat = 26
        static let headingLeading: CGFloat = SpacingTokens.md2
        static let headingTrailing: CGFloat = SpacingTokens.md2 + SpacingTokens.xxxs
        static let boxInset: CGFloat = SpacingTokens.xs2
        static let glyphSlot: CGFloat = SpacingTokens.md1
        static let glyphGap: CGFloat = SpacingTokens.xxs3
        static let lineOneHeight: CGFloat = 17
        static let separatorLeading: CGFloat = SpacingTokens.xs2 + SpacingTokens.md1 + SpacingTokens.xxs3
        static let separatorOpacity: Double = 0.1
        static let dotSize: CGFloat = SpacingTokens.xxs3
        static let hollowDotWidth: CGFloat = 1.3
        static let sqlMaxLines = 8
    }
}
