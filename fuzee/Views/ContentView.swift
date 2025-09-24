//
//  ContentView.swift
//  fuzee
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingAddConnection = false

    var body: some View {
        NavigationSplitView {
                SidebarView(
                    connections: $appModel.connections,
                    selectedConnectionID: $appModel.selectedConnectionID,
                    databaseStructure: $appModel.databaseStructure,
                    onAddConnection: {
                        showingAddConnection = true
                        appState.showSheet(.connectionEditor)
                    },
                    onDeleteConnection: { id in
                        Task { await appModel.deleteConnection(id: id) }
                    }
                )
                .environmentObject(appModel)
                .environmentObject(appState)
                .navigationTitle("Connections")
                .frame(minWidth: 220)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            } detail: {
                if let selected = appModel.selectedConnection,
                   let session = appModel.session {
                    QueryView(connection: selected, session: session).navigationTitle(selected.connectionName).environmentObject(appState).background(themeManager.windowBackground)
                } else if let selected = appModel.selectedConnection {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("Not Connected")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Connect to \(selected.connectionName) to run queries and browse the database schema.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 12) {
                            Button("Connect") {
                                Task {
                                    appState.isConnecting = true
                                    await appModel.connect(to: selected)
                                    appState.isConnecting = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large).disabled(appState.isConnecting)

                            Button("Edit Connection") {
                                showingAddConnection = true
                                appState.showSheet(.connectionEditor)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        if appState.isConnecting {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Connecting...").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(selected.connectionName).background(themeManager.windowBackground)
                } else {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No Connection Selected")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Create or select a connection from the sidebar to get started.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Add Connection") {
                            showingAddConnection = true
                            appState.showSheet(.connectionEditor)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Fuzee").background(themeManager.windowBackground)
                }
        }
        .navigationSplitViewStyle(.balanced).background(themeManager.windowBackground)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button("Add Connection...") {
                        showingAddConnection = true
                        appState.showSheet(.connectionEditor)
                    }
                    
                    Divider()
                    
                    Button("Settings...") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }.keyboardShortcut(",", modifiers: .command)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                }
                .menuStyle(.borderlessButton)
                .help("Application Menu")
            }
        }
        .sheet(isPresented: $showingAddConnection) {
            ConnectionEditorView(
                connection: appModel.selectedConnection,
                onSave: { conn, password in
                    Task {
                        await appModel.upsertConnection(conn, password: password)
                    }
                }
            )
            .frame(minWidth: 420, minHeight: 420).environmentObject(appState)
        }
        .task {
            await appModel.load()
        }
        .onChange(of: appModel.selectedConnectionID) { _, newValue in
            // Remove auto-connect to avoid state publishing warnings
            // Users will need to manually click "Connect" button
        }.onChange(of: appState.activeSheet) {
            _, newSheet in
            showingAddConnection = (newSheet == .connectionEditor)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
}
