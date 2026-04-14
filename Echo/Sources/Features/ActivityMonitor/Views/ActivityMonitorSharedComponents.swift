import SwiftUI

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let isSystem: Bool

    init(text: String, isSystem: Bool = false) {
        self.text = text.isEmpty ? (isSystem ? "System" : "Unknown") : text
        self.isSystem = isSystem
    }

    var body: some View {
        Text(text)
            .font(TypographyTokens.Table.status)
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        if isSystem { return ColorTokens.Status.info }
        switch text.lowercased() {
        case "active", "running", "runnable": return ColorTokens.Status.success
        case "sleeping", "idle": return ColorTokens.Text.secondary
        case "suspended", "blocked": return ColorTokens.Status.error
        default: return ColorTokens.Text.secondary
        }
    }
}

// MARK: - Section Info Button

struct SectionInfoButton: View {
    let info: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(TypographyTokens.compact)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show info")
        .popover(isPresented: $isPresented) {
            Text(info)
                .font(TypographyTokens.detail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.sm)
                .frame(width: 250)
        }
    }
}

// MARK: - Empty Table Placeholder

struct EmptyTablePlaceholder: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Activity Data", systemImage: "tablecells")
        } description: {
            Text("Waiting for data\u{2026}")
        }
    }
}

// MARK: - pg_stat_statements Guide

struct PGStatStatementsGuide: View {
    let onOpenManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .foregroundStyle(ColorTokens.Status.info)
                Text("Enable Expensive Query Tracking")
                    .font(TypographyTokens.headline)
            }

            Text("PostgreSQL requires the `pg_stat_statements` extension to track detailed query performance metrics.")
                .font(TypographyTokens.detail)

            VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                Label("Add to `shared_preload_libraries` in `postgresql.conf`", systemImage: "1.circle")
                Label("Restart the PostgreSQL server", systemImage: "2.circle")
                Label("Run `CREATE EXTENSION pg_stat_statements;`", systemImage: "3.circle")
            }
            .font(TypographyTokens.detail)
            .foregroundStyle(ColorTokens.Text.secondary)

            Button("Open Extension Manager") {
                onOpenManager()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, SpacingTokens.xxs)
        }
        .padding(SpacingTokens.lg)
        .frame(width: 380)
    }
}

// MARK: - Section Container

struct SectionContainer<Content: View>: View {
    let title: String
    let icon: String
    let info: String?
    let content: () -> Content

    init(title: String, icon: String, info: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.info = info
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: icon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .foregroundStyle(ColorTokens.accent)
                Text(title.uppercased())
                    .font(TypographyTokens.detail.weight(.bold))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .kerning(0.5)

                if let info = info {
                    SectionInfoButton(info: info)
                }
            }
            .padding(.leading, SpacingTokens.xxxs)
            content()
                .background(ColorTokens.Background.secondary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.medium)
                        .stroke(ColorTokens.Text.primary.opacity(0.05), lineWidth: 1)
                )
        }
    }
}
