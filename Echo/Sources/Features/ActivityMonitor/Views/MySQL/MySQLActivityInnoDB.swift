import SwiftUI
import MySQLKit

struct MySQLActivityInnoDB: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @State private var statusSections: [InnoDBSection] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedSections: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .task { await load() }
    }

    private var toolbar: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("InnoDB Engine Status")
                .font(TypographyTokens.headline)

            Spacer()

            Button(expandedSections.isEmpty ? "Expand All" : "Collapse All") {
                if expandedSections.isEmpty {
                    expandedSections = Set(statusSections.map(\.title))
                } else {
                    expandedSections = []
                }
            }
            .buttonStyle(.borderless)

            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.sm)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && statusSections.isEmpty {
            ActivitySectionLoadingView(
                title: "InnoDB Status",
                subtitle: "Running SHOW ENGINE INNODB STATUS\u{2026}"
            )
        } else if let errorMessage {
            ContentUnavailableView {
                Label("InnoDB Status Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
        } else if statusSections.isEmpty {
            ContentUnavailableView {
                Label("No Data", systemImage: "cylinder")
            } description: {
                Text("InnoDB status output was empty.")
            }
        } else {
            sectionList
        }
    }

    private var sectionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                ForEach(statusSections) { section in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSections.contains(section.title) },
                            set: { expanded in
                                if expanded {
                                    expandedSections.insert(section.title)
                                } else {
                                    expandedSections.remove(section.title)
                                }
                            }
                        )
                    ) {
                        Text(section.body)
                            .font(TypographyTokens.monospaced)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(SpacingTokens.sm)
                            .background(ColorTokens.Background.secondary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } label: {
                        Label(section.title, systemImage: sectionIcon(for: section.title))
                            .font(TypographyTokens.headline)
                    }
                }
            }
            .padding(SpacingTokens.md)
        }
    }

    private func sectionIcon(for title: String) -> String {
        switch title {
        case "TRANSACTIONS": return "arrow.left.arrow.right"
        case "SEMAPHORES": return "flag"
        case "FILE I/O": return "externaldrive"
        case "BUFFER POOL AND MEMORY": return "memorychip"
        case "LOG": return "doc.text"
        case "ROW OPERATIONS": return "tablecells"
        case "LATEST DETECTED DEADLOCK": return "lock.trianglebadge.exclamationmark"
        case "INSERT BUFFER AND ADAPTIVE HASH INDEX": return "list.bullet.indent"
        case "BACKGROUND THREAD": return "gearshape.2"
        default: return "info.circle"
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let status = try await viewModel.loadMySQLInnoDBStatus()
            statusSections = parseInnoDBStatus(status.statusText)
            expandedSections = Set(statusSections.prefix(3).map(\.title))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func parseInnoDBStatus(_ text: String) -> [InnoDBSection] {
        let lines = text.components(separatedBy: "\n")
        var sections: [InnoDBSection] = []
        var currentTitle: String?
        var currentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Section headers are preceded and followed by dashed separator lines
            if trimmed.hasPrefix("---") && trimmed.allSatisfy({ $0 == "-" || $0 == " " }) {
                continue
            }

            // Known section headers are ALL CAPS lines
            if isKnownSectionHeader(trimmed) {
                if let title = currentTitle, !currentLines.isEmpty {
                    sections.append(InnoDBSection(title: title, body: currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentTitle = trimmed
                currentLines = []
            } else if currentTitle != nil {
                currentLines.append(line)
            }
        }

        // Append last section
        if let title = currentTitle, !currentLines.isEmpty {
            sections.append(InnoDBSection(title: title, body: currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return sections
    }

    private func isKnownSectionHeader(_ line: String) -> Bool {
        let knownHeaders: Set<String> = [
            "BACKGROUND THREAD",
            "SEMAPHORES",
            "LATEST DETECTED DEADLOCK",
            "LATEST FOREIGN KEY ERROR",
            "TRANSACTIONS",
            "FILE I/O",
            "INSERT BUFFER AND ADAPTIVE HASH INDEX",
            "LOG",
            "BUFFER POOL AND MEMORY",
            "INDIVIDUAL BUFFER POOL INFO",
            "ROW OPERATIONS"
        ]
        return knownHeaders.contains(line)
    }
}

private struct InnoDBSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}
