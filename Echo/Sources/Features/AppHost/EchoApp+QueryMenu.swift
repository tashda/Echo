//
//  EchoApp+QueryMenu.swift
//  Echo
//

import SwiftUI
#if os(macOS)
import AppKit

/// The Query menu (plan K1, K3): every run mode, Cancel, EchoSense, Format and Validate. It owns
/// their shortcuts, so the toolbar buttons bind none. Titles double as keys for custom shortcuts.
/// Run's item becomes Stop Query while the tab runs, so ⌘↩ toggles (round 20).
struct QueryMenuCommands: Commands {
    let tabStore: TabStore
    let navigationStore: NavigationStore
    let projectStore: ProjectStore

    private var customShortcuts: [String: CustomShortcutBinding] {
        projectStore.globalSettings.customKeyboardShortcuts ?? [:]
    }

    /// Reads only whether a query tab is in front and running, not its SQL, so typing doesn't
    /// rebuild the menu; each action checks the rest.
    private var queryTab: WorkspaceTab? {
        guard navigationStore.isWorkspaceWindowKey, let tab = tabStore.activeTab, tab.query != nil else { return nil }
        return tab
    }

    private var isRunning: Bool { queryTab?.query?.isExecuting ?? false }

    var body: some Commands {
        CommandMenu("Query") {
            ForEach(QueryRunMode.allCases) { mode in
                if mode == .run {
                    runOrStopItem
                } else {
                    Button {
                        queryTab?.run(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                    .shortcut(Self.shortcut(for: mode), custom: customShortcuts)
                    .disabled(queryTab == nil || isRunning || (mode.needsPlans && !(queryTab?.supportsExecutionPlans ?? false)))
                }
            }

            if let tab = queryTab, tab.supportsRunAsOneTransaction {
                Toggle("Run as One Transaction", isOn: tab.runAsOneTransactionBinding)
                    .disabled(isRunning)
            }

            Button {
                queryTab?.query?.cancelExecution()
            } label: {
                Label("Cancel Query", systemImage: "stop.fill")
            }
            .shortcut(Self.cancel, custom: customShortcuts)
            .disabled(!isRunning)

            Divider()

            Button {
                NSApp.sendAction(#selector(NSTextView.complete(_:)), to: nil, from: nil)
            } label: {
                Label("Show EchoSense Suggestions", systemImage: "text.badge.star")
            }
            .shortcut(Self.echoSense, custom: customShortcuts)
            .disabled(queryTab == nil)

            Button {
                guard let tab = queryTab else { return }
                Task { await tab.formatSQL() }
            } label: {
                Label("Format Query", systemImage: "sparkles")
            }
            .shortcut(Self.format, custom: customShortcuts)
            .disabled(queryTab == nil)

            Button {
                queryTab?.validateSQL()
            } label: {
                Label("Validate Query", systemImage: "exclamationmark.triangle")
            }
            .shortcut(Self.validate, custom: customShortcuts)
            .disabled(queryTab == nil)
        }
    }
}

// MARK: - Run and Stop

extension QueryMenuCommands {
    /// ⌘↩ toggles (round 20, owner's note): Run, or Stop while the tab's query runs.
    @ViewBuilder
    var runOrStopItem: some View {
        Button {
            guard let tab = queryTab, let query = tab.query else { return }
            if query.isExecuting {
                if query.cancelPhase == nil { query.cancelExecution() }
            } else {
                tab.run(.run)
            }
        } label: {
            if isRunning {
                Label("Stop Query", systemImage: "stop.fill")
            } else {
                Label(QueryRunMode.run.title, systemImage: QueryRunMode.run.systemImage)
            }
        }
        .shortcut(Self.shortcut(for: .run), custom: customShortcuts)
        .disabled(queryTab == nil)
    }
}

// MARK: - Default shortcuts

extension QueryMenuCommands {
    struct DefaultShortcut {
        let title: String
        let key: KeyEquivalent
        let modifiers: EventModifiers
    }

    static func shortcut(for mode: QueryRunMode) -> DefaultShortcut {
        switch mode {
        case .run: DefaultShortcut(title: "Run Selected Query", key: .return, modifiers: .command)
        case .statementAtCursor: DefaultShortcut(title: mode.title, key: .return, modifiers: [.command, .shift])
        case .explain: DefaultShortcut(title: mode.title, key: "e", modifiers: [.command, .option])
        case .explainAnalyze: DefaultShortcut(title: mode.title, key: "e", modifiers: [.command, .option, .shift])
        }
    }

    /// ⌘. stays EchoSense (owner, muscle memory), so Cancel takes ⌥⌘. until the owner picks.
    static let cancel = DefaultShortcut(title: "Cancel Query", key: ".", modifiers: [.command, .option])
    static let echoSense = DefaultShortcut(title: "Show EchoSense Suggestions", key: ".", modifiers: .command)
    static let format = DefaultShortcut(title: "Format Query", key: "f", modifiers: [.command, .shift])
    /// Off ⇧⌘V, which is Paste and Match Style; ⇧⌘B is Analyze in Xcode.
    static let validate = DefaultShortcut(title: "Validate Query", key: "b", modifiers: [.command, .shift])
}

private extension QueryRunMode {
    var needsPlans: Bool { self == .explain || self == .explainAnalyze }
}

private extension View {
    func shortcut(_ shortcut: QueryMenuCommands.DefaultShortcut, custom: [String: CustomShortcutBinding]) -> some View {
        let binding = custom[shortcut.title]
        return keyboardShortcut(binding?.swiftUIKey ?? shortcut.key, modifiers: binding?.swiftUIModifiers ?? shortcut.modifiers)
    }
}
#endif
