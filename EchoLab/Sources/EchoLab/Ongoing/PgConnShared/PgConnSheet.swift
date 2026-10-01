import SwiftUI

/// Round 23's shared drawing of the PostgreSQL connection sheet (CON-1.2): grouped sections of
/// label-and-value rows, as `ConnectionEditorView` lays them out. Read-only sample values.
struct PgConnSheet<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) { content() }
                .padding(SpacingTokens.md)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .labScrollSizing()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }
}

/// One grouped section: an optional header and rows separated by hairlines.
struct PgConnSection<Content: View>: View {
    var header: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if let header {
                Text(header).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.leading, SpacingTokens.xs)
            }
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                Group(subviews: content()) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().padding(.leading, SpacingTokens.sm) }
                        row.padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xs)
                    }
                }
            }
            .background(ColorTokens.Text.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small))
        }
    }
}

/// A label on the left and its control on the right, optionally with the sheet's ⓘ.
struct PgConnRow<Content: View>: View {
    let title: String
    var info = false
    var highlighted = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Text(title).font(TypographyTokens.formLabel)
            if info {
                Image(systemName: "info.circle").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            Spacer(minLength: SpacingTokens.md)
            content()
        }
        .overlay(alignment: .leading) {
            if highlighted {
                Capsule().fill(ColorTokens.accent).frame(width: 3).padding(.vertical, -2).offset(x: -SpacingTokens.xs)
            }
        }
    }
}

/// A text field's value, or its grey prompt.
struct PgConnValue: View {
    let text: String
    var prompt = false
    var secure = false

    var body: some View {
        Text(secure && !prompt ? "••••••••" : text)
            .font(TypographyTokens.formValue)
            .foregroundStyle(prompt ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
            .lineLimit(1)
    }
}

/// A pop-up menu button.
struct PgConnMenu: View {
    let text: String

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Text(text).font(TypographyTokens.formValue).lineLimit(1)
            Image(systemName: "chevron.up.chevron.down").font(TypographyTokens.detail)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .padding(.vertical, SpacingTokens.xxxs)
        .background(ColorTokens.Text.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall))
    }
}

struct PgConnSwitch: View {
    let isOn: Bool
    var disabled = false

    var body: some View {
        Toggle("", isOn: .constant(isOn)).labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(disabled)
    }
}

/// A path field with Browse, as the certificate rows are drawn.
struct PgConnPath: View {
    let text: String
    var prompt = false

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            PgConnValue(text: text, prompt: prompt)
            Button("Browse") {}.controlSize(.small)
        }
    }
}

/// A line of explanation inside a section, the way the sheet's descriptions read.
struct PgConnNote: View {
    let text: String
    var icon: String?
    var color: Color = ColorTokens.Text.secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xxs) {
            if let icon { Image(systemName: icon).foregroundStyle(color) }
            Text(text).foregroundStyle(icon == nil ? color : ColorTokens.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(TypographyTokens.formDescription)
        .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
    }
}

/// The Server section as Echo draws it (CON-2.2, CON-2.3): engine, server:port, database.
struct PgConnServerSection<Extra: View>: View {
    var host = "db1.corp.example.com"
    var hostPrompt = false
    var port: String = "5432"
    var database = "reporting"
    var title = "New Connection"
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        PgConnSection(header: title) {
            HStack(spacing: SpacingTokens.none) {
                ForEach(["PostgreSQL", "MySQL", "SQL Server", "SQLite"], id: \.self) { name in
                    Text(name).font(TypographyTokens.detail)
                        .frame(maxWidth: .infinity).padding(.vertical, SpacingTokens.xxxs)
                        .background(name == "PostgreSQL" ? ColorTokens.Text.primary.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall))
                }
            }
            PgConnRow(title: "Server") {
                HStack(spacing: SpacingTokens.xxs2) {
                    PgConnValue(text: host, prompt: hostPrompt)
                    Text(":").foregroundStyle(ColorTokens.Text.tertiary)
                    PgConnValue(text: port, prompt: port == "5432")
                }
            }
            extra()
            PgConnRow(title: "Database") { PgConnValue(text: database) }
        }
    }
}

extension PgConnServerSection where Extra == EmptyView {
    init(host: String = "db1.corp.example.com", port: String = "5432", database: String = "reporting") {
        self.init(host: host, port: port, database: database, extra: { EmptyView() })
    }
}

/// The Security and timeouts disclosure's header row (CON-4.1).
struct PgConnDisclosure: View {
    let summary: String
    var expanded = true

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: expanded ? "chevron.down" : "chevron.right").font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.secondary)
            Text("Security and timeouts").font(TypographyTokens.formLabel)
            Spacer(minLength: SpacingTokens.md)
            Text(summary).font(TypographyTokens.formValue).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
        }
    }
}

/// The sheet's bottom bar (CON-6.2): Test, the result in one line, a fix button, Save.
struct PgConnTestBar: View {
    enum Kind { case success, error, info }
    let result: String
    var kind: Kind = .error
    var fix: String?

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            Button("Test") {}.controlSize(.small)
            Label(result, systemImage: kind == .error ? "xmark.circle.fill" : kind == .success ? "checkmark.circle.fill" : "info.circle")
                .font(TypographyTokens.formDescription)
                .foregroundStyle(kind == .error ? ColorTokens.Status.error : kind == .success ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let fix { Button(fix) {}.controlSize(.small) }
            Spacer(minLength: SpacingTokens.xs)
            Button("Save and Connect") {}.controlSize(.small).buttonStyle(.borderedProminent)
        }
        .frame(minWidth: 300)
    }
}
