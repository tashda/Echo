//
//  EchoApp.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct EchoApp: App {
    @State private var coordinator = AppDirector.shared

    init() {
        EchoApp.raiseFileDescriptorLimit()
        FontRegistrar.registerBundledFonts()
        #if os(macOS)
        if let forced = ProcessInfo.processInfo.environment["ECHO_FORCE_APPEARANCE"] {
            switch forced.lowercased() {
            case "dark":
                NSApp?.appearance = NSAppearance(named: .darkAqua)
            case "light":
                NSApp?.appearance = NSAppearance(named: .aqua)
            default:
                break
            }
        }
        #endif
    }

    var body: some Scene {
        SwiftUI.WindowGroup {
            WorkspaceView()
                .environment(coordinator.projectStore)
                .environment(coordinator.connectionStore)
                .environment(coordinator.navigationStore)
                .environment(coordinator.tabStore)
                .environment(coordinator.resultSpoolConfigCoordinator)
                .environment(coordinator.diagramBuilder)
                .environment(coordinator.navigationStore.navigationState)
                .environment(coordinator.environmentState)
                .environment(coordinator.appState)
                .environment(coordinator.clipboardHistory)
                .environment(coordinator.appearanceStore)
                .environment(coordinator.notificationEngine)
                .environment(coordinator.activityEngine)
                .environment(coordinator.authState)
                .task { await coordinator.initialize() }
        }
        .defaultLaunchBehavior(.presented)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            QueryCommands(
                environmentState: coordinator.environmentState,
                appState: coordinator.appState,
                navigationStore: coordinator.navigationStore,
                tabStore: coordinator.tabStore,
                projectStore: coordinator.projectStore
            )
            AboutCommands()
            AppSettingsCommands()
            SparkleCommands()
#if os(macOS)
            ConnectMenuCommands(
                environmentState: coordinator.environmentState,
                projectStore: coordinator.projectStore,
                connectionStore: coordinator.connectionStore,
                navigationStore: coordinator.navigationStore
            )
            ViewMenuCommands(
                appState: coordinator.appState,
                navigationStore: coordinator.navigationStore,
                tabStore: coordinator.tabStore
            )
#endif
#if DEBUG
            AutocompleteInspectorCommands()
            PerformanceMonitorCommands()
            StreamingTestHarnessCommands()
#endif
        }
        JobQueueWindow()
        UserEditorWindow()
        LoginEditorWindow()
        RoleEditorWindow()
        DatabaseEditorWindow()
        ServerEditorWindow()
        FunctionEditorWindow()
        PgRoleEditorWindow()
        PublicationEditorWindow()
        SubscriptionEditorWindow()
        TablePropertiesWindow()
        PermissionManagerWindow()
        TriggerEditorWindow()
        ViewEditorWindow()
        SequenceEditorWindow()
        TypeEditorWindow()
        DatabaseMailEditorWindow()
        SettingsWindowScene()
        AboutWindowScene()
#if DEBUG
        AutocompleteInspectorWindow()
        PerformanceMonitorWindow()
        StreamingTestHarnessWindow()
#endif
    }

    /// Raises the per-process file descriptor limit so NIO's kqueue and the many
    /// dedicated SQL Server connections don't exhaust the default 256 fd ceiling.
    private static func raiseFileDescriptorLimit() {
        var limits = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &limits) == 0 else { return }
        limits.rlim_cur = min(limits.rlim_max, 8192)
        setrlimit(RLIMIT_NOFILE, &limits)
    }
}

#if os(macOS)
@MainActor
struct QueryCommands: Commands {
    var environmentState: EnvironmentState
    var appState: AppState
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let projectStore: ProjectStore

    private var customShortcuts: [String: CustomShortcutBinding] {
        projectStore.globalSettings.customKeyboardShortcuts ?? [:]
    }

    private func key(for title: String, default defaultKey: KeyEquivalent) -> KeyEquivalent {
        customShortcuts[title]?.swiftUIKey ?? defaultKey
    }

    private func mods(for title: String, default defaultMods: EventModifiers) -> EventModifiers {
        customShortcuts[title]?.swiftUIModifiers ?? defaultMods
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button {
                environmentState.openQueryTab()
            } label: {
                Label("New Query Tab", systemImage: "plus.square.on.square")
            }
            .keyboardShortcut(key(for: "New Query Tab", default: "t"), modifiers: mods(for: "New Query Tab", default: [.command]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activateNextTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Label("Next Tab", systemImage: "chevron.right.square")
            }
            .keyboardShortcut(key(for: "Next Tab", default: .tab), modifiers: mods(for: "Next Tab", default: [.control]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activatePreviousTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Label("Previous Tab", systemImage: "chevron.left.square")
            }
            .keyboardShortcut(key(for: "Previous Tab", default: .tab), modifiers: mods(for: "Previous Tab", default: [.control, .shift]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                if tabStore.reopenLastClosedTab(activate: true) != nil {
                    if appState.showTabOverview {
                        appState.showTabOverview = false
                    }
                }
            }) {
                Label("Reopen Closed Tab", systemImage: "arrow.uturn.backward.square")
            }
            .keyboardShortcut(key(for: "Reopen Closed Tab", default: "t"), modifiers: mods(for: "Reopen Closed Tab", default: [.command, .shift]))

            Button {
                if navigationStore.isWorkspaceWindowKey {
                    if let active = tabStore.activeTab {
                        tabStore.closeTab(id: active.id)
                    }
                } else if let keyWindow = NSApplication.shared.keyWindow {
                    keyWindow.performClose(nil)
                }
            } label: {
                Label("Close Query Tab", systemImage: "xmark.square")
            }
            .keyboardShortcut(key(for: "Close Query Tab", default: "w"), modifiers: mods(for: "Close Query Tab", default: [.command]))
        }
    }
}

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button {
                openWindow(id: AboutWindowScene.sceneID)
            } label: {
                Label("About Echo", systemImage: "info.circle")
            }
        }
    }
}

struct AutocompleteInspectorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: AutocompleteInspectorWindow.sceneID)
            } label: {
                Label("Autocomplete Management", systemImage: "text.magnifyingglass")
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
        }
    }
}

struct PerformanceMonitorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: PerformanceMonitorWindow.sceneID)
            } label: {
                Label("Performance Monitor", systemImage: "waveform.path.ecg")
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}

struct StreamingTestHarnessCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button {
                openWindow(id: StreamingTestHarnessWindow.sceneID)
            } label: {
                Label("Streaming Test Harness", systemImage: "dot.radiowaves.left.and.right")
            }
            .keyboardShortcut("t", modifiers: [.command, .option, .shift])
        }
    }
}

struct AppSettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button {
                openWindow(id: SettingsWindowScene.sceneID)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}

struct SparkleCommands: Commands {
    private var updater = SparkleUpdater.shared

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button {
                updater.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.clockwise.circle")
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }
}

#endif
