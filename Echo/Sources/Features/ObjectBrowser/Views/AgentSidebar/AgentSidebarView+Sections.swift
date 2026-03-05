import SwiftUI
import SQLServerKit

extension AgentSidebarView {
    @ViewBuilder
    var agentGroups: some View {
        group("Jobs", isExpanded: $expandedJobs) {
            let jobs = viewModel.jobs.filter { searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            if jobs.isEmpty {
                placeholder("No jobs found")
            } else {
                ForEach(jobs) { job in
                    HStack(spacing: 8) {
                        Image(systemName: job.enabled ? "checkmark.circle.fill" : "slash.circle")
                            .foregroundStyle(job.enabled ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(job.name).lineLimit(1)
                            if let outcome = job.lastOutcome {
                                Text(outcome).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.xxs)
                }
            }
        }

        group("Alerts", isExpanded: $expandedAlerts) {
            if viewModel.alerts.isEmpty {
                placeholder("No alerts found")
            } else {
                ForEach(viewModel.alerts) { alert in
                    HStack(spacing: 8) {
                        Image(systemName: alert.enabled ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .foregroundStyle(alert.enabled ? .yellow : .secondary)
                        Text(alert.name).lineLimit(1)
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.xxs)
                }
            }
        }

        group("Operators", isExpanded: $expandedOperators) {
            if viewModel.operators.isEmpty {
                placeholder("No operators found")
            } else {
                ForEach(viewModel.operators) { op in
                    HStack(spacing: 8) {
                        Image(systemName: op.enabled ? "person.fill" : "person")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(op.name).lineLimit(1)
                            if let email = op.email, !email.isEmpty { Text(email).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.xxs)
                }
            }
        }

        group("Proxies", isExpanded: $expandedProxies) {
            if viewModel.proxies.isEmpty {
                placeholder("No proxies found")
            } else {
                ForEach(viewModel.proxies) { px in
                    HStack(spacing: 8) {
                        Image(systemName: px.enabled ? "shield.fill" : "shield")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(px.name).lineLimit(1)
                            if let cred = px.credentialName { Text(cred).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.xxs)
                }
            }
        }

        group("Error Logs", isExpanded: $expandedErrorLogs) {
            if viewModel.errorLogs.isEmpty {
                placeholder("No error logs visible")
            } else {
                ForEach(viewModel.errorLogs) { log in
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Archive #\(log.archiveNumber)")
                            Text(log.date).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.md)
                    .padding(.vertical, SpacingTokens.xxs)
                }
            }
        }
    }

    func group(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.label.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title.uppercased())
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, SpacingTokens.md)
            }
            .buttonStyle(.plain)
            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    @ViewBuilder
    func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, SpacingTokens.md)
            .padding(.vertical, SpacingTokens.xxxs)
    }
}
