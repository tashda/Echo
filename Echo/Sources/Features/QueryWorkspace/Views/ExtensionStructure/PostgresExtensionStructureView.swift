import SwiftUI

struct PostgresExtensionStructureView: View {
    @Bindable var tab: WorkspaceTab
    var viewModel: PostgresExtensionStructureViewModel

    @Environment(EnvironmentState.self) private var environmentState
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading extension details\u{2026}")
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
            if viewModel.objects.isEmpty {
                await viewModel.reload()
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(alignment: .center, spacing: SpacingTokens.sm) {
                Image(systemName: "puzzlepiece.fill")
                    .font(TypographyTokens.hero)
                    .foregroundStyle(ColorTokens.Status.success)
                
                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text(viewModel.extensionName)
                        .font(TypographyTokens.standard.weight(.bold))
                    
                    HStack(spacing: SpacingTokens.xxs) {
                        Text("PostgreSQL Extension")
                        if let current = viewModel.currentVersion {
                            Text("• v\(current)")
                        }
                    }
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    
                    if let desc = viewModel.description {
                        Text(desc)
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                            .lineLimit(2)
                            .padding(.top, SpacingTokens.xxxs)
                    }
                }
                
                Spacer()
                
                HStack(spacing: SpacingTokens.sm) {
                    if let home = viewModel.homepageURL, let url = URL(string: home) {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            Image(systemName: "safari")
                        }
                        .buttonStyle(.plain)
                        .help("Visit Homepage")
                    }
                    
                    if let docs = viewModel.documentationURL, let url = URL(string: docs) {
                        Button(action: { NSWorkspace.shared.open(url) }) {
                            Image(systemName: "doc.text")
                        }
                        .buttonStyle(.plain)
                        .help("View Documentation")
                    }
                }
                .font(TypographyTokens.prominent)
                .foregroundStyle(ColorTokens.Text.secondary)
                .padding(.trailing, SpacingTokens.xs)
                
                if viewModel.canUpdate {
                    Button(action: { Task { await viewModel.update() } }) {
                        if viewModel.isUpdating {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Update to v\(viewModel.latestVersion ?? "?")", systemImage: "arrow.up.circle.fill")
                                .foregroundStyle(.white)
                                .padding(.horizontal, SpacingTokens.xs)
                                .padding(.vertical, SpacingTokens.xxs)
                                .background(ColorTokens.Status.info)
                                .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.small))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isUpdating)
                }
                
                Button(action: { Task { await viewModel.reload() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(TypographyTokens.detail)
            }
        }
        .padding(SpacingTokens.lg)
        .background(ColorTokens.Background.secondary.opacity(0.5))
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Owned Objects (\(viewModel.objects.count))")
                .font(TypographyTokens.standard.weight(.semibold))
                .padding(.horizontal, SpacingTokens.lg)
                .padding(.vertical, SpacingTokens.md)
            
            Divider()
            
            if viewModel.objects.isEmpty {
                VStack {
                    Spacer()
                    Text("No objects owned by this extension.")
                        .font(TypographyTokens.detail)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.objects) { object in
                        HStack(spacing: SpacingTokens.sm) {
                            Image(systemName: iconForType(object.type))
                                .foregroundStyle(ColorTokens.Text.secondary)
                                .frame(width: 16)
                            
                            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                                Text(object.name)
                                    .font(TypographyTokens.standard)
                                Text(object.schema)
                                    .font(TypographyTokens.caption2)
                                    .foregroundStyle(ColorTokens.Text.tertiary)
                            }
                            
                            Spacer()
                            
                            Text(object.type)
                                .font(TypographyTokens.label)
                                .foregroundStyle(ColorTokens.Text.quaternary)
                        }
                        .padding(.vertical, SpacingTokens.xxs)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.uppercased() {
        case "TABLE": return "tablecells"
        case "VIEW": return "eye"
        case "INDEX": return "shippingbox"
        case "FUNCTION": return "function"
        case "TYPE": return "square.stack.3d.up"
        case "SEQUENCE": return "list.number"
        default: return "cube"
        }
    }
}
