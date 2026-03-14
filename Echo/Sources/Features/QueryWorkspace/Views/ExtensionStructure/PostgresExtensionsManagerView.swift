import SwiftUI

struct PostgresExtensionsManagerView: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var viewModel: PostgresExtensionsManagerViewModel
    
    @EnvironmentObject private var environmentState: EnvironmentState
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading extensions\u{2026}")
                    Spacer()
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: SpacingTokens.md) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(TypographyTokens.hero)
                        .foregroundStyle(ColorTokens.Status.warning)
                    Text(error)
                        .font(TypographyTokens.standard)
                    Button("Retry") {
                        Task { await viewModel.reload() }
                    }
                    Spacer()
                }
            } else {
                content
            }
        }
        .background(ColorTokens.Background.primary)
        .task {
            await viewModel.reload()
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(alignment: .center, spacing: SpacingTokens.sm) {
                Image(systemName: "puzzlepiece")
                    .font(TypographyTokens.hero)
                    .foregroundStyle(ColorTokens.Status.info)
                
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text("Extension Manager")
                        .font(TypographyTokens.standard.weight(.bold))
                    
                    Text(viewModel.databaseName)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $viewModel.selectedTab) {
                    ForEach(PostgresExtensionsManagerViewModel.Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                Button(action: { Task { await viewModel.reload() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail)
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ColorTokens.Text.tertiary)
                TextField("Search extensions\u{2026}", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(SpacingTokens.xs)
            .background(ColorTokens.Text.primary.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }
    
    private var content: some View {
        Group {
            if viewModel.selectedTab == .installed {
                installedList
            } else {
                marketplaceList
            }
        }
    }
    
    private var installedList: some View {
        List {
            if viewModel.filteredInstalled.isEmpty {
                Text("No extensions found.")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .padding()
            } else {
                ForEach(viewModel.filteredInstalled) { ext in
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "puzzlepiece.fill")
                            .foregroundStyle(ColorTokens.Status.success)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                            Text(ext.name)
                                .font(TypographyTokens.standard.weight(.medium))
                            if let comment = ext.comment {
                                Text(comment)
                                    .font(TypographyTokens.caption2)
                                    .foregroundStyle(ColorTokens.Text.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("View Structure") {
                            // Find matching SchemaObjectInfo and open it
                            openStructure(for: ext)
                        }
                        .buttonStyle(.plain)
                        .font(TypographyTokens.label)
                        .foregroundStyle(ColorTokens.Status.info)
                        
                        Menu {
                            Button(role: .destructive) {
                                Task { await viewModel.dropExtension(ext.name) }
                            } label: {
                                Label("Drop Extension", systemImage: "trash")
                            }
                            
                            Button(role: .destructive) {
                                Task { await viewModel.dropExtension(ext.name, cascade: true) }
                            } label: {
                                Label("Drop Cascade", systemImage: "exclamationmark.shield")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .padding(.vertical, SpacingTokens.xxs2)
                }
            }
        }
        .listStyle(.inset)
    }
    
    private var marketplaceList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.lg) {
                // Section 1: Available on Server
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    Text("Available on Server")
                        .font(TypographyTokens.standard.weight(.bold))
                        .foregroundStyle(ColorTokens.Text.secondary)
                    
                    if viewModel.availableOnServer.filter({ $0.installedVersion == nil }).isEmpty {
                        Text("All server extensions are already installed.")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    } else {
                        ForEach(viewModel.availableOnServer.filter({ $0.installedVersion == nil })) { ext in
                            availableRow(name: ext.name, comment: ext.comment, version: ext.defaultVersion)
                        }
                    }
                }
                
                Divider()
                
                // Section 2: Online Marketplace
                VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                    HStack {
                        Text("Community Marketplace")
                            .font(TypographyTokens.standard.weight(.bold))
                            .foregroundStyle(ColorTokens.Text.secondary)
                        Spacer()
                        Text("Powered by PGXN")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    
                    if viewModel.marketplaceExtensions.isEmpty {
                        VStack(spacing: SpacingTokens.xs) {
                            Image(systemName: "network.slash")
                                .font(TypographyTokens.hero)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                            Text("Marketplace currently unavailable.")
                                .font(TypographyTokens.detail)
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(viewModel.filteredMarketplace) { ext in
                            communityRow(ext)
                        }
                    }
                }
            }
            .padding(SpacingTokens.lg)
        }
    }
    
    @ViewBuilder
    private func availableRow(name: String, comment: String?, version: String) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "puzzlepiece")
                .foregroundStyle(ColorTokens.Text.secondary)
            
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(name)
                    .font(TypographyTokens.standard.weight(.medium))
                if let comment {
                    Text(comment)
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            
            Spacer()
            
            Text("v\(version)")
                .font(TypographyTokens.label)
                .foregroundStyle(ColorTokens.Text.tertiary)
            
            Button("Install") {
                Task { await viewModel.installExtension(name) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!viewModel.isSuperuser)
        }
        .padding(SpacingTokens.xs2)
        .background(ColorTokens.Text.primary.opacity(0.03))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func communityRow(_ ext: CommunityExtension) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "globe")
                .foregroundStyle(ColorTokens.Status.info)
            
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack(spacing: SpacingTokens.xxs2) {
                    Text(ext.name)
                        .font(TypographyTokens.standard.weight(.medium))
                    if ext.isTLE {
                        Text("TLE")
                            .font(TypographyTokens.compact.weight(.bold))
                            .padding(.horizontal, SpacingTokens.xxs)
                            .padding(.vertical, 1)
                            .background(ColorTokens.Status.success.opacity(0.2))
                            .foregroundStyle(ColorTokens.Status.success)
                            .cornerRadius(4)
                    }
                }
                if let desc = ext.description {
                    Text(desc)
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let home = ext.homepage, let url = URL(string: home) {
                Button { NSWorkspace.shared.open(url) } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.Status.info)
            }
            
            if viewModel.hasTLE && ext.isTLE {
                Button("Quick Install") {
                    Task { await viewModel.installExtension(ext.name) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Requires Host Install")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .padding(SpacingTokens.xs2)
        .background(ColorTokens.Text.primary.opacity(0.03))
        .cornerRadius(8)
    }
    
    private func openStructure(for object: SchemaObjectInfo) {
        guard let session = environmentState.sessionCoordinator.sessionForConnection(tab.connection.id) else { return }
        session.addExtensionStructureTab(extensionName: object.name, databaseName: viewModel.databaseName)
    }
}
