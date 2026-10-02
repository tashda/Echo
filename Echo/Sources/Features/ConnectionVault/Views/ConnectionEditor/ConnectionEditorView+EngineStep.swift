import SwiftUI

/// Round MC, step one of a new connection, "Which database?" (the title sits in the editor's
/// toolbar). WD1: a grouped form like System Settings. One row per engine with its symbol and a
/// short note; the one used last shows a Return keycap and answers Return. Below, a row for a
/// connection string, with an example in the footer. Double-clicking the example puts it in the
/// field with its first part selected; Tab moves to the next part; Return reads the string and
/// opens the form filled in.
extension ConnectionEditorView {
    var engineStep: some View {
        Form {
            Section {
                ForEach(DatabaseType.allCases, id: \.self) { type in
                    engineChoiceRow(type)
                }
            }

            Section {
                connectionStringRow
            } footer: {
                connectionStringFooter
            }
        }
        .formStyle(.grouped)
        .modifier(EngineStepSizing(isSheet: presentation == .sheet))
    }

    // MARK: Engine rows

    @ViewBuilder
    private func engineChoiceRow(_ type: DatabaseType) -> some View {
        let isLast = type == lastEngine
        let isHovered = hoveredEngine == type
        Button { chooseEngine(type) } label: {
            HStack(spacing: SpacingTokens.sm) {
                Image(type.iconName)
                    .font(TypographyTokens.prominent)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .frame(width: EngineRowMetrics.badgeSize, height: EngineRowMetrics.badgeSize)
                    .background(ColorTokens.Workspace.groupFill,
                                in: RoundedRectangle(cornerRadius: EngineRowMetrics.badgeCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    HStack(spacing: SpacingTokens.xxs2) {
                        Text(type.shortDisplayName)
                            .font(TypographyTokens.standard.weight(.semibold))
                            .foregroundStyle(ColorTokens.Text.primary)
                        if type.isBeta {
                            Text("BETA")
                                .font(TypographyTokens.label.weight(.bold))
                                .foregroundStyle(ColorTokens.Status.warning)
                                .padding(.horizontal, SpacingTokens.xxs2)
                                .padding(.vertical, SpacingTokens.micro)
                                .background(ColorTokens.Status.warning.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(engineNote(type))
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: SpacingTokens.xs)

                if isLast {
                    // The last-used engine answers Return; a keycap says so.
                    Image(systemName: "return")
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .padding(.vertical, SpacingTokens.xxxs)
                        .overlay(
                            RoundedRectangle(cornerRadius: SpacingTokens.xxs, style: .continuous)
                                .strokeBorder(ColorTokens.Text.tertiary, lineWidth: 0.5)
                        )
                } else {
                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
            .padding(.vertical, SpacingTokens.xxxs)
            .padding(.horizontal, SpacingTokens.xxs2)
            .background(isHovered ? ColorTokens.Surface.hover : Color.clear,
                        in: RoundedRectangle(cornerRadius: SpacingTokens.xxs2, style: .continuous))
            .padding(.horizontal, -SpacingTokens.xxs2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(DefaultActionIf(isLast))
        .onHover { hovering in
            if hovering { hoveredEngine = type } else if hoveredEngine == type { hoveredEngine = nil }
        }
        .accessibilityLabel(type.displayName)
        .accessibilityHint(isLast ? "The engine you used last. Press Return to choose it." : "")
    }

    /// The one line under each engine's name.
    private func engineNote(_ type: DatabaseType) -> String {
        switch type {
        case .postgresql: "Open source, port 5432"
        case .mysql: "Port 3306"
        case .microsoftSQL: "Microsoft, port 1433"
        case .sqlite: "A file on this Mac"
        }
    }

    func chooseEngine(_ type: DatabaseType) {
        selectedDatabaseType = type
        lastEngineRawValue = type.rawValue
        withAnimation(motion.standard) { step = .form }
        focusedField = .host
    }

    // MARK: Connection string

    private var connectionStringRow: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "link")
                .foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: EngineRowMetrics.badgeSize)
            TextField("", text: $connectionString, selection: $connectionStringSelection, prompt: Text("Or paste a connection string").font(TypographyTokens.standard))
                .labelsHidden()
                .textFieldStyle(.plain)
                .font(connectionString.isEmpty ? TypographyTokens.standard : TypographyTokens.standard.monospaced())
                .onSubmit(readConnectionString)
                .onKeyPress(.tab) { selectNextConnectionStringPart() ? .handled : .ignored }
                .onChange(of: connectionString) { oldValue, newValue in
                    connectionStringIssue = nil
                    connectionStringParts.removeAll { !newValue.contains($0) }
                    // A paste (many characters at once) is read straight away.
                    if newValue.count - oldValue.count > 8, connectionStringParts.isEmpty,
                       ConnectionStringParser.parse(newValue) != nil {
                        readConnectionString()
                    }
                }
        }
        .frame(minHeight: InsetRowMetrics.minHeight)
    }

    /// The issue (after Return on a string Echo can't read), then the example.
    private var connectionStringFooter: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if let issue = connectionStringIssue {
                Label(issue, systemImage: "exclamationmark.circle.fill")
                    .font(TypographyTokens.formDescription)
                    .foregroundStyle(ColorTokens.Status.error)
            }
            connectionStringExample
        }
    }

    private var exampleEngine: DatabaseType { hoveredEngine ?? lastEngine }

    private var connectionStringExample: some View {
        let example = ConnectionStringExample.for(exampleEngine)
        return HStack(spacing: SpacingTokens.xxs2) {
            Text("\(exampleEngine.shortDisplayName):")
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(example.text)
                .font(TypographyTokens.detail.monospaced())
                .foregroundStyle(ColorTokens.Text.secondary)
                .underline(pattern: .dot, color: ColorTokens.Text.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .onTapGesture(count: 2) { useExample(example) }
                .help("Double-click to edit this in the field")
        }
        .font(TypographyTokens.detail)
    }

    /// Puts the example in the field and selects its first part, ready to type over.
    private func useExample(_ example: ConnectionStringExample) {
        connectionString = example.text
        connectionStringParts = example.parts
        selectPart(example.parts.first, after: nil)
    }

    /// Tab: select the next part that still holds its placeholder. Returns false when there is
    /// none left, so Tab moves focus as usual.
    private func selectNextConnectionStringPart() -> Bool {
        guard !connectionStringParts.isEmpty else { return false }
        var caret: String.Index? = nil
        if case .selection(let range)? = connectionStringSelection?.indices {
            caret = range.upperBound
        }
        for part in connectionStringParts where selectPart(part, after: caret) { return true }
        for part in connectionStringParts where selectPart(part, after: nil) { return true }
        return false
    }

    @discardableResult
    private func selectPart(_ part: String?, after caret: String.Index?) -> Bool {
        guard let part else { return false }
        let start = caret ?? connectionString.startIndex
        guard start <= connectionString.endIndex,
              let range = connectionString.range(of: part, range: start..<connectionString.endIndex) else { return false }
        connectionStringSelection = TextSelection(range: range)
        return true
    }

    /// Return in the field: read the string, take its engine and open the form filled in.
    func readConnectionString() {
        let text = connectionString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let parsed = ConnectionStringParser.parse(text) else {
            connectionStringIssue = "Echo can't read this. Compare it with the example below."
            return
        }
        lastEngineRawValue = parsed.databaseType.rawValue
        applyPastedConnectionString(text, allowsEngineChange: true)
        withAnimation(motion.standard) { step = .form }
    }
}

/// The example under the connection string field, and the parts Tab visits.
struct ConnectionStringExample: Equatable {
    let text: String
    let parts: [String]

    static func `for`(_ type: DatabaseType) -> ConnectionStringExample {
        switch type {
        case .postgresql:
            ConnectionStringExample(text: "postgres://user@host:5432/database", parts: ["user", "host", "5432", "database"])
        case .mysql:
            ConnectionStringExample(text: "mysql://user@host:3306/database", parts: ["user", "host", "3306", "database"])
        case .microsoftSQL:
            ConnectionStringExample(text: "Server=host;Database=database;User Id=user", parts: ["host", "database", "user"])
        case .sqlite:
            ConnectionStringExample(text: "file:///Users/you/Data/app.sqlite", parts: ["/Users/you/Data/app.sqlite"])
        }
    }
}

/// Return chooses the row of the engine used last.
private struct DefaultActionIf: ViewModifier {
    let isOn: Bool
    init(_ isOn: Bool) { self.isOn = isOn }

    func body(content: Content) -> some View {
        if isOn {
            content.keyboardShortcut(.defaultAction)
        } else {
            content
        }
    }
}

/// The engine rows' symbol badge (WD1).
enum EngineRowMetrics {
    static let badgeSize: CGFloat = 28
    static let badgeCornerRadius: CGFloat = 7
    /// The sheet's floor for the engine step (see `EngineStepSizing`).
    static let sheetMinHeight: CGFloat = 300
}

/// In a sheet the engine step is as tall as its rows (no scrolling, no empty band); inline, in
/// Manage Connections, it fills the pane and scrolls when the pane is short.
private struct EngineStepSizing: ViewModifier {
    let isSheet: Bool

    func body(content: Content) -> some View {
        if isSheet {
            content
                .scrollDisabled(true)
                // A floor in case the grouped form reports no ideal height; just under the
                // height of the four rows, the string row and its footer.
                .frame(minHeight: EngineRowMetrics.sheetMinHeight)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            content
        }
    }
}
