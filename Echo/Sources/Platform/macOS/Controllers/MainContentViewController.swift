//
//  MainContentViewController.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//

import AppKit
import SwiftUI

final class MainContentViewController: NSViewController {
    private let tabID: UUID?
    private let appModel: AppModel
    private let appState: AppState
    private let clipboardHistory: ClipboardHistoryStore
    private var hostingController: NSHostingController<MainContentWrapperView>?

    init(
        tabID: UUID?,
        appModel: AppModel,
        appState: AppState,
        clipboardHistory: ClipboardHistoryStore
    ) {
        self.tabID = tabID
        self.appModel = appModel
        self.appState = appState
        self.clipboardHistory = clipboardHistory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let contentView = MainContentWrapperView(
            tabID: tabID,
            appModel: appModel,
            appState: appState,
            clipboardHistory: clipboardHistory,
            themeManager: ThemeManager.shared
        )
        let hosting = NSHostingController(rootView: contentView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let container = NSView()
        container.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        self.hostingController = hosting
        self.view = container
    }
}

private struct MainContentWrapperView: View {
    let tabID: UUID?
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState
    @ObservedObject var clipboardHistory: ClipboardHistoryStore
    @Environment(\.useNativeTabBar) private var useNativeTabBar
    @ObservedObject var themeManager: ThemeManager

    private var selectedConnection: SavedConnection? { appModel.selectedConnection }
    private var selectedSession: ConnectionSession? {
        guard let connection = selectedConnection else { return nil }
        return appModel.sessionManager.sessionForConnection(connection.id)
    }

    var body: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let contentBottomPadding = max(safeArea.bottom, 18)

            VStack(spacing: 8) {
                if showsTabStrip {
                    WorkspaceTabStrip(
                        leadingPadding: 18,
                        trailingPadding: 18,
                        createNewTab: createNewTab,
                        toggleOverview: { appState.showTabOverview.toggle() }
                    )
                    .frame(height: 44)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }

                queryContent
                    .padding(.leading, safeArea.leading)
                    .padding(.trailing, safeArea.trailing)
                    .padding(.bottom, contentBottomPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.windowBackground)
        }
        .environmentObject(appModel)
        .environmentObject(appState)
        .environmentObject(clipboardHistory)
        .environmentObject(themeManager)
        .safeAreaInset(edge: .top, spacing: 0) {
            GeometryReader { proxy in
                WorkspaceTopToolbar(availableWidth: max(proxy.size.width - 24, 320))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 44)
            .background(.bar)
        }
    }

    private var queryContent: some View {
        Group {
            if let connection = selectedConnection, let session = selectedSession {
                if appModel.tabManager.activeTab != nil {
                    TabbedQueryView(showsTabStrip: false)
                        .environmentObject(appModel)
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                } else {
                    ActiveConnectionView(connection: connection, session: session)
                        .environmentObject(appModel)
                        .environmentObject(appState)
                }
            } else if let connection = selectedConnection {
                DisconnectedConnectionView(connection: connection)
                    .environmentObject(appModel)
                    .environmentObject(appState)
            } else {
                NoConnectionSelectedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func createNewTab() {
        guard let activeSession = appModel.sessionManager.activeSession else { return }
        appModel.openQueryTab(for: activeSession)
    }

    private var showsTabStrip: Bool {
        !useNativeTabBar && !appModel.tabManager.tabs.isEmpty
    }
}

private struct ActiveConnectionView: View {
    let connection: SavedConnection
    let session: ConnectionSession
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Connected to \(connection.connectionName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(session.selectedDatabaseName.map { "Database: \($0)" } ?? "No database selected")
                .foregroundStyle(.secondary)

            Button("Disconnect") {
                Task { await appModel.disconnectSession(withID: session.id) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DisconnectedConnectionView: View {
    let connection: SavedConnection
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Not Connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect to \(connection.connectionName) to start working.")
                .foregroundStyle(.secondary)

            Button("Connect") {
                Task { await appModel.connect(to: connection) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoConnectionSelectedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("No Connection Selected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Open or add a connection to get started.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
