import SwiftUI
import SQLServerKit

extension DatabaseMailEditorView {

    var statusSection: some View {
        Group {
            if let status = viewModel.status {
                Section("Service") {
                    PropertyRow(title: "Status") {
                        HStack(spacing: SpacingTokens.xxs) {
                            Circle()
                                .fill(status.isStarted ? ColorTokens.Status.success : ColorTokens.Status.error)
                                .frame(width: 8, height: 8)
                            Text(status.statusDescription)
                                .font(TypographyTokens.standard)
                        }
                    }

                    Toggle("Database Mail Service", isOn: serviceToggleBinding)
                        .disabled(viewModel.isSaving || !canConfigure)
                        .help(canConfigure ? "" : "Requires sysadmin role")
                }

                if !viewModel.profiles.isEmpty {
                    Section("Test") {
                        Button("Send Test Email") {
                            viewModel.showSendTest = true
                        }
                        .disabled(!canConfigure)
                        .help(canConfigure ? "" : "Requires sysadmin role")
                    }
                }

                if !viewModel.eventLogEntries.isEmpty {
                    Section("Recent Events") {
                        ForEach(viewModel.eventLogEntries) { entry in
                            eventLogRow(entry)
                        }
                    }
                }
            }
        }
    }

    private var serviceToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.status?.isStarted ?? false },
            set: { newValue in
                Task {
                    if newValue {
                        await viewModel.startMail(session: session)
                    } else {
                        await viewModel.stopMail(session: session)
                    }
                }
            }
        )
    }

    private func eventLogRow(_ entry: SQLServerMailEventLogEntry) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            HStack {
                Image(systemName: eventLogIcon(entry.eventType))
                    .font(TypographyTokens.detail)
                    .foregroundStyle(eventLogColor(entry.eventType))
                Text(entry.eventType.capitalized)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(eventLogColor(entry.eventType))
                Spacer()
                if let date = entry.logDate {
                    VStack(alignment: .trailing, spacing: SpacingTokens.xxxs) {
                        Text(date, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Text.secondary)
                        Text("\(date, style: .relative) ago")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.Text.tertiary)
                    }
                }
            }
            if let desc = entry.description, !desc.isEmpty {
                Text(desc)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, SpacingTokens.xxs)
    }

    private func eventLogIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "error": "exclamationmark.circle.fill"
        case "warning": "exclamationmark.triangle.fill"
        case "information": "info.circle.fill"
        case "success": "checkmark.circle.fill"
        default: "circle.fill"
        }
    }

    private func eventLogColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "error": ColorTokens.Status.error
        case "warning": ColorTokens.Status.warning
        case "success": ColorTokens.Status.success
        case "information": ColorTokens.accent
        default: ColorTokens.Text.tertiary
        }
    }
}
