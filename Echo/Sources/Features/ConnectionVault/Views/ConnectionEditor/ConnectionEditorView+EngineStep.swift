import SwiftUI

/// Round MC, step one of a new connection: "Which database?" Four tiles with the engine symbols
/// (no ports), the one used last answering Return, and a field for a connection string with an
/// example under it. Double-clicking the example puts it in the field with its first part
/// selected; Tab moves to the next part; Return reads the string and opens the form filled in.
extension ConnectionEditorView {
    var engineStep: some View {
        VStack(spacing: SpacingTokens.md) {
            Text("Which database?")
                .font(TypographyTokens.title2.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.top, SpacingTokens.xs)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: SpacingTokens.xs), GridItem(.flexible())], spacing: SpacingTokens.xs) {
                ForEach(DatabaseType.allCases, id: \.self) { type in
                    engineTile(type)
                }
            }

            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                connectionStringField
                if let issue = connectionStringIssue {
                    Label(issue, systemImage: "exclamationmark.circle.fill")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Status.error)
                        .padding(.leading, SpacingTokens.sm)
                }
                connectionStringExample
            }
        }
        .padding(.horizontal, SpacingTokens.lg)
        .padding(.bottom, SpacingTokens.lg)
    }

    // MARK: Tiles

    @ViewBuilder
    private func engineTile(_ type: DatabaseType) -> some View {
        let isLast = type == lastEngine
        Button { chooseEngine(type) } label: {
            VStack(spacing: SpacingTokens.xxs2) {
                Image(type.iconName)
                    .font(.system(size: EngineTileMetrics.symbolSize))
                    .foregroundStyle(ColorTokens.Text.primary)
                    .frame(height: EngineTileMetrics.symbolSize + SpacingTokens.xxs)
                Text(type.shortDisplayName)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.Text.primary)
                Text(tileCaption(type, isLast: isLast))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: EngineTileMetrics.height)
            .background(ColorTokens.Background.tertiary, in: RoundedRectangle(cornerRadius: EngineTileMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: EngineTileMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(ColorTokens.Text.primary.opacity(0.08), lineWidth: 0.5)
            }
            .overlay(alignment: .bottomTrailing) {
                // The last-used engine answers Return; a keycap says so instead of a ring that
                // reads as a selection.
                if isLast {
                    Image(systemName: "return")
                        .font(TypographyTokens.caption2.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .padding(.horizontal, SpacingTokens.xxs)
                        .padding(.vertical, SpacingTokens.xxxs)
                        .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xxs, style: .continuous).strokeBorder(ColorTokens.Text.tertiary, lineWidth: 0.5))
                        .padding(SpacingTokens.xs)
                }
            }
            .overlay(alignment: .topTrailing) {
                if type.isBeta {
                    Text("BETA")
                        .font(TypographyTokens.caption2.weight(.bold))
                        .foregroundStyle(ColorTokens.Status.warning)
                        .padding(.horizontal, SpacingTokens.xxs2)
                        .padding(.vertical, SpacingTokens.nano)
                        .background(ColorTokens.Status.warning.opacity(0.15), in: Capsule())
                        .padding(SpacingTokens.xs)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: EngineTileMetrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(DefaultActionIf(isLast))
        .onHover { hovering in
            if hovering { hoveredEngine = type } else if hoveredEngine == type { hoveredEngine = nil }
        }
        .accessibilityLabel(type.displayName)
        .accessibilityHint(isLast ? "The engine you used last. Press Return to choose it." : "")
    }

    private func tileCaption(_ type: DatabaseType, isLast: Bool) -> String {
        if type == .sqlite { return "A file on this Mac" }
        return isLast ? "Used last" : " "
    }

    func chooseEngine(_ type: DatabaseType) {
        selectedDatabaseType = type
        lastEngineRawValue = type.rawValue
        withAnimation(motion.standard) { step = .form }
        focusedField = .host
    }

    // MARK: Connection string

    private var connectionStringField: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: "link")
                .foregroundStyle(ColorTokens.Text.secondary)
            TextField("", text: $connectionString, selection: $connectionStringSelection, prompt: Text("Or paste a connection string").font(TypographyTokens.standard))
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
        .padding(.horizontal, SpacingTokens.md)
        .frame(height: EngineTileMetrics.fieldHeight)
        .glassEffect(.regular, in: .capsule)
    }

    private var exampleEngine: DatabaseType { hoveredEngine ?? lastEngine }

    private var connectionStringExample: some View {
        let example = ConnectionStringExample.for(exampleEngine)
        return HStack(spacing: SpacingTokens.xxs2) {
            Text("\(exampleEngine.shortDisplayName):")
                .foregroundStyle(ColorTokens.Text.secondary)
            Text(example.text)
                .font(TypographyTokens.detail.monospaced())
                .foregroundStyle(ColorTokens.Text.primary)
                .underline(pattern: .dot, color: ColorTokens.Text.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .onTapGesture(count: 2) { useExample(example) }
                .help("Double-click to edit this in the field")
        }
        .font(TypographyTokens.detail)
        .padding(.leading, SpacingTokens.md)
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

/// Return chooses the tile of the engine used last.
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

enum EngineTileMetrics {
    static let symbolSize: CGFloat = 30
    static let height: CGFloat = 104
    static let cornerRadius: CGFloat = 18
    static let fieldHeight: CGFloat = 36
}
