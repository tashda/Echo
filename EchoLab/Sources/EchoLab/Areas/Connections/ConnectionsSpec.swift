import SwiftUI

/// Connections by piece, each with a stable ID (`CON-4.2`). Every value below was read from
/// `ConnectionEditorView` and `ManageConnectionsView`.
@MainActor
enum ConnectionsSpec {
    private static let editor = "Echo/Sources/Features/ConnectionVault/Views/ConnectionEditor/"
    private static let manage = "Echo/Sources/Features/ConnectionVault/Views/ManageConnections/"
    private static let workspace = "Echo/Sources/Features/AppHost/Views/Navigation/WorkspaceView.swift"
    private static let tokens = "Packages/EchoDesignSystem/Sources/EchoDesignSystem/Tokens/LayoutToken+ManageConnections.swift"
    private static let r14 = "ported.Round 14 · connections"

    static func spec<Specimen: View>(stageHeight: CGFloat, @ViewBuilder specimen: @escaping () -> Specimen) -> AreaSpec {
        AreaSpec(code: "CON", stageHeight: stageHeight, parts: parts, specimen: specimen)
    }

    private static let parts: [SpecPart] = [
        SpecPart(number: "1", name: "Presentations", summary: "One form, shown three ways.", elements: [
            SpecElement(number: "1.1", name: "Quick Connect sheet", summary: "For a one-off connection. Opened from the rail's + menu.", groups: [
                .layout(.row("Width", "520pt", token: "ConnectionEditorView.body"), .row("Height", "360pt minimum, 520 ideal, 720 maximum")),
                .behaviour(.row("Save to Connections", "off at first; name, folder and colour stay hidden"),
                           .row("Connect", "connects once; the password is still saved in the Keychain (CR6)"),
                           .row("Save to Connections on", "the button reads Save and Connect")),
            ], rounds: [r14], files: [editor + "ConnectionEditorView.swift", workspace]),
            SpecElement(number: "1.2", name: "New Connection sheet", summary: "The same sheet, for a connection to keep.", groups: [
                .behaviour(.row("Save to Connections", "always on: no toggle; a \"Saved As\" section holds name, folder and colour"),
                           .row("Buttons", "Cancel, Save, Save and Connect (default)")),
            ], rounds: [r14], files: [editor + "ConnectionEditorView.swift", workspace]),
            SpecElement(number: "1.3", name: "Inline pane", summary: "The form beside the list in Manage Connections.", groups: [
                .behaviour(.row("Buttons", "Revert (rebuilds from the saved connection), Connect, Save (default)"),
                           .row("Editing", "existing connections are edited only here")),
                .layout(.row("Button row padding", "12pt (the sheet's is 20pt)", token: "SpacingTokens.sm / md2")),
            ], rounds: [r14], files: [editor + "ConnectionEditorView+TestToolbar.swift", manage + "ManageConnectionEditorPane.swift"]),
        ]),
        SpecPart(number: "2", name: "Server", summary: "The first group of the form.", elements: [
            SpecElement(number: "2.1", name: "Group title", summary: "\"Quick Connect\", \"New Connection\", or the connection's name.", groups: [
                .type(.row("Style", "the grouped form's section header")),
            ], files: [editor + "ConnectionEditorView+Detail.swift"]),
            SpecElement(number: "2.2", name: "Engine", summary: "A segmented control labelled Database.", groups: [
                .layout(.row("Segments", "SQL Server · PostgreSQL · MySQL · SQLite", token: "DatabaseType.shortDisplayName")),
                .behaviour(.row("Change", "the port takes the new engine's default unless you changed it; choosing SQLite clears the sign-in and TLS")),
            ], files: [editor + "ConnectionEditorView+Detail.swift", editor + "ConnectionEditorView+Support.swift"]),
            SpecElement(number: "2.3", name: "Server and port", summary: "One row: the host, a colon, the port.", groups: [
                .layout(.row("Port field", "32pt wide", token: "SpacingTokens.xxl"), .row("Alignment", "values right-aligned")),
                .behaviour(.row("Server prompt", "db.example.com or a connection URL"), .row("Port prompt", "the engine's default port")),
            ], files: [editor + "ConnectionEditorView+Detail.swift"]),
            SpecElement(number: "2.4", name: "Database", summary: "The database to open; optional.", groups: [
                .behaviour(.row("Prompt", "Default")),
            ], files: [editor + "ConnectionEditorView+Detail.swift"]),
            SpecElement(number: "2.5", name: "SQLite file", summary: "For SQLite, Server and port become Database File.", groups: [
                .behaviour(.row("Prompt", "~/Data/app.sqlite"), .row("Choose", "opens a file panel for sqlite, sqlite3, db and db3 files"),
                           .row("No name given", "the connection is named after the file")),
            ], files: [editor + "ConnectionEditorView+Actions.swift"]),
        ]),
        SpecPart(number: "3", name: "Sign In", summary: "Not shown for SQLite.", elements: [
            SpecElement(number: "3.1", name: "Method", summary: "Where the credentials come from.", groups: [
                .behaviour(.row("Manual", "typed here"), .row("Identity", "a saved identity, with a + to create one"),
                           .row("Inherit", "from the folder's identity; offered only when the connection is in a folder"),
                           .row("Windows integrated", "only Manual")),
            ], files: [editor + "ConnectionEditorView+DetailSections.swift"]),
            SpecElement(number: "3.2", name: "Manual fields", summary: "Mechanism, domain, user and password (or a token).", groups: [
                .behaviour(.row("Mechanism", "a menu, only when the engine offers more than one"), .row("Domain", "only for Windows authentication"),
                           .row("Access token", "replaces user and password; prompt JWT access token"),
                           .row("Password prompt", "•••••••• when one is saved and untouched; otherwise password")),
            ], files: [editor + "ConnectionEditorView+DetailSections.swift"]),
            SpecElement(number: "3.3", name: "Identity", summary: "Pick a saved identity.", groups: [
                .behaviour(.row("None saved", "\"No identities available.\" with a Create Identity button"),
                           .row("Some saved", "a menu and a small + button")),
            ], files: [editor + "ConnectionEditorView+DetailSections.swift"]),
            SpecElement(number: "3.4", name: "Inherit", summary: "Shows the folder's identity.", groups: [
                .behaviour(.row("Found", "Inherited: its name, and \"Inherited from folder.\""), .row("Not found", "Inherited: None, in the error colour")),
            ], files: [editor + "ConnectionEditorView+DetailSections.swift"]),
        ]),
        SpecPart(number: "4", name: "Security and timeouts", summary: "One disclosure; closed at first.", elements: [
            SpecElement(number: "4.1", name: "Disclosure", summary: "Its right side summarises the values.", groups: [
                .behaviour(.row("Summary", "SQL Server: Optional · 30 s. PostgreSQL: TLS prefer · 30 s. MySQL: TLS or No TLS · 30 s. SQLite: 30 s"),
                           .row("Remembers", "whether you opened it (connectionEditor.optionsExpanded)")),
                .motion(.row("Disclosure", "system")),
            ], files: [editor + "ConnectionEditorView+Detail.swift"]),
            SpecElement(number: "4.2", name: "SQL Server rows", summary: "Encryption, certificate and intent.", groups: [
                .behaviour(.row("Encryption", "a menu: Optional (default), Mandatory, Strict (TDS 8.0)"), .row("Trust Server Certificate", "a switch"),
                           .row("Read-Only Intent", "a switch, for AlwaysOn replica routing"),
                           .row("Host Name In Certificate", "a field, only while not trusting the certificate"),
                           .row("CA Certificate Path", "a field with Browse, only while not trusting")),
            ], files: [editor + "ConnectionEditorView+SecuritySection.swift"]),
            SpecElement(number: "4.3", name: "PostgreSQL rows", summary: "SSL mode and certificates.", groups: [
                .behaviour(.row("SSL Mode", "a menu"), .row("CA Certificate Path", "for verify-ca and verify-full"),
                           .row("Client Certificate and Client Key", "unless the mode is disable")),
            ], files: [editor + "ConnectionEditorView+SecuritySection.swift"]),
            SpecElement(number: "4.4", name: "MySQL row", summary: "Use SSL/TLS, a switch.", groups: [.behaviour(.row("Use SSL/TLS", "a switch"))], files: [editor + "ConnectionEditorView+SecuritySection.swift"]),
            SpecElement(number: "4.5", name: "Timeouts", summary: "Connection and query timeouts, in seconds.", groups: [
                .layout(.row("Fields", "60pt wide, right-aligned, followed by \"seconds\"")),
                .behaviour(.row("Prompts", "30 for connection, 60 for query")),
            ], files: [editor + "ConnectionEditorView+DetailSections.swift"]),
        ]),
        SpecPart(number: "5", name: "Saved as", summary: "Only while saving.", elements: [
            SpecElement(number: "5.1", name: "Save to Connections", summary: "A toggle in Quick Connect.", groups: [
                .behaviour(.row("Off", "name, folder and colour are hidden"), .row("On", "they appear")),
                .motion(.row("Toggle", "animated")),
            ], files: [editor + "ConnectionEditorView+Detail.swift"]),
            SpecElement(number: "5.2", name: "Name and folder", summary: "Optional name; a folder menu.", groups: [
                .behaviour(.row("Name prompt", "the server, or My Connection"), .row("Left empty", "the connection is named after its server (or SQLite file)"),
                           .row("Folder", "a menu of folders by path (None first)")),
            ], files: [editor + "ConnectionEditorView+Detail.swift", editor + "ConnectionEditorView+Actions.swift"]),
            SpecElement(number: "5.3", name: "Colour", summary: "Five swatches and a colour picker.", groups: [
                .layout(.row("Swatch", "20pt circle", token: "SpacingTokens.md2"), .row("Selected ring", "accent, 2pt, 3pt outside", token: "ColorTokens.accent")),
                .behaviour(.row("Palette", "5A9CDE, 6EAE72, E8943A, 9B72CF, D4687A", token: "ConnectionEditorView.colorPalette")),
                .motion(.row("Select", "ease in-out, 0.15s")),
            ], files: [editor + "ConnectionEditorView+Detail.swift"]),
        ]),
        SpecPart(number: "6", name: "Footer and checks", summary: "The button row, testing and validation.", elements: [
            SpecElement(number: "6.1", name: "Buttons", summary: "What the row holds depends on the presentation.", groups: [
                .behaviour(.row("Quick Connect", "Test … Cancel, Connect or Save and Connect (default)"),
                           .row("New Connection", "Test … Cancel, Save, Save and Connect (default)"),
                           .row("Inline", "Test … Revert, Connect, Save (default)")),
                .layout(.row("Padding", "20pt in the sheet, 12pt inline"), .row("Above it", "a divider")),
            ], files: [editor + "ConnectionEditorView+TestToolbar.swift"]),
            SpecElement(number: "6.2", name: "Test", summary: "Tries the connection; one line of result (CR4).", groups: [
                .behaviour(.row("Testing", "the button becomes Cancel Test; a small spinner and \"Testing\""),
                           .row("Result", "the last log line, with an icon (✓ success, ✕ error, ⓘ info), truncated; click for the whole log in a popover"),
                           .row("Log", "monospaced 11pt, time, then the message; selectable")),
            ], rounds: [r14], files: [editor + "ConnectionEditorView+TestToolbar.swift", editor + "ConnectionEditorView+Testing.swift"]),
            SpecElement(number: "6.3", name: "Validation", summary: "Buttons are never disabled; missing fields are named (CR1).", groups: [
                .behaviour(.row("Server", "Enter the server's host name or address. (SQLite: Choose a database file.)"), .row("Port", "Enter a port between 1 and 65535."),
                           .row("User", "Enter a user name. / Choose an identity. / The folder has no identity to inherit."),
                           .row("Windows", "Enter the Windows domain. / Enter the Windows password."), .row("Token", "Enter an access token."),
                           .row("On press", "the messages show and the first field takes focus, in the order server, port, user, domain, password, name")),
                .type(.row("Style", "red exclamation icon and text", token: "TypographyTokens.formDescription")),
            ], rounds: [r14], files: [editor + "ConnectionEditorView+Support.swift"]),
            SpecElement(number: "6.4", name: "Paste a connection", summary: "A URL or string pasted into Server fills the form (CR3).", groups: [
                .behaviour(.row("Fills", "engine, server, port, database, user and password")),
            ], files: [editor + "ConnectionEditorView+Support.swift", "Echo/Sources/Features/ConnectionVault/Domain/ConnectionStringParser.swift"]),
        ]),
        SpecPart(number: "7", name: "Manage Connections", summary: "The window where connections are managed and edited.", elements: [
            SpecElement(number: "7.1", name: "Window", summary: "A split view with the sidebar, list and editor pane.", groups: [
                .layout(.row("Minimum size", "1100 × 600pt", token: "ManageConnectionsView+Layout"), .row("Style", "balanced")),
            ], rounds: [r14], files: [manage + "ManageConnectionsView+Layout.swift"]),
            SpecElement(number: "7.2", name: "Sidebar", summary: "Connections, Identities and Projects, with folders.", groups: [
                .layout(.row("Width", "240pt minimum, 260 ideal, 400 maximum")),
                .type(.row("Section headers", "caption bold, secondary")),
                .behaviour(.row("Rows", "All Connections, All Identities, then their folders"), .row("Right-click", "a menu per section, folder and project")),
            ], files: [manage + "ManageConnectionsView+Sidebar.swift"]),
            SpecElement(number: "7.3", name: "Toolbar", summary: "Add, and search.", groups: [
                .behaviour(.row("+ menu", "New Connection, New Identity, New Folder"), .row("Search", "a field in the toolbar, prompt Search"),
                           .row("Projects", "Export Project, New Project and a ⋯ menu")),
            ], files: [manage + "ManageConnectionsView+Detail.swift"]),
            SpecElement(number: "7.4", name: "List", summary: "A table of connections.", groups: [
                .layout(.row("Minimum width", "320pt", token: "LayoutTokens.ManageConnections.listMinWidth")),
                .behaviour(.row("Double-click", "connects"), .row("Actions", "connect, edit, duplicate, delete, move to a folder")),
            ], rounds: [r14], files: [manage + "ConnectionsTableView.swift", tokens]),
            SpecElement(number: "7.5", name: "Editor pane", summary: "The selected connection's form.", groups: [
                .layout(.row("Width", "380pt minimum, 460pt ideal", token: "editorMinWidth / editorIdealWidth"), .row("Split", "HSplitView, list on the left")),
                .behaviour(.row("Rebuilds", "when another connection is selected, or on Revert")),
            ], rounds: [r14], files: [manage + "ManageConnectionEditorPane.swift", tokens]),
            SpecElement(number: "7.6", name: "Nothing selected", summary: "A placeholder in the pane.", groups: [
                .behaviour(.row("Shows", "\"No Connection Selected\", \"Select a connection to edit it here.\" and a New Connection button")),
            ], files: [manage + "ManageConnectionEditorPane.swift"]),
            SpecElement(number: "7.7", name: "Delete", summary: "Always confirmed.", groups: [
                .behaviour(.row("Alert", "Are you sure you want to delete … ? This action cannot be undone."), .row("Buttons", "Delete (destructive), Cancel")),
            ], files: [manage + "ManageConnectionsView+Layout.swift"]),
        ]),
    ]
}
