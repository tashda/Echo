import SwiftUI

// Design Lab: interactive previews of the canvas-and-cards redesign, built with plain SwiftUI and
// sample data so each option can be judged on real Liquid Glass before it is wired into Echo.
// Open any file in this folder and use Xcode's canvas. Nothing here ships in release builds.

/// Motion speeds from the review: Default and Fast. Every lab animation goes through this.
enum LabSpeed: String, CaseIterable, Identifiable {
    case standard = "Default"
    case fast = "Fast"

    var id: String { rawValue }
    var scale: Double { self == .fast ? 0.7 : 1 }

    /// The app's motion values at this speed, so the lab moves exactly like Echo.
    func motion(reduceMotion: Bool = false) -> EchoMotion {
        EchoMotion(durationScale: self == .fast ? InterfaceMotionSpeed.fast.durationScale : 1, reduceMotion: reduceMotion)
    }

    /// Echo's house spring: bouncy, scaled by speed; a short fade when Reduce Motion is on.
    func spring(reduceMotion: Bool = false) -> Animation {
        motion(reduceMotion: reduceMotion).standard
    }
}

/// Sample servers used across the lab.
struct LabServer: Identifiable, Hashable {
    let id: String
    let name: String
    let monogram: String
    let color: Color
    var isConnecting = false

    static let samples: [LabServer] = [
        LabServer(id: "pg18", name: "postgres18", monogram: "18", color: .blue),
        LabServer(id: "tippr", name: "tippr", monogram: "TI", color: .green),
        LabServer(id: "pg16", name: "pg16-lab", monogram: "16", color: .orange),
        LabServer(id: "wh", name: "warehouse", monogram: "WH", color: .purple),
        LabServer(id: "rp", name: "reporting-replica", monogram: "RP", color: .teal),
    ]
}

/// Sample tree: servers → databases → folders → objects.
struct LabTreeDatabase: Identifiable, Hashable {
    let id: String
    let name: String
    let tables: [String]
}

enum LabTree {
    static let databases: [String: [LabTreeDatabase]] = [
        "pg18": [
            LabTreeDatabase(id: "pg18.employees", name: "employees", tables: ["department", "department_employee", "department_manager", "employee", "salary", "title"]),
            LabTreeDatabase(id: "pg18.lego", name: "lego", tables: ["lego_colors", "lego_inventories", "lego_inventory_parts", "lego_parts", "lego_sets", "lego_themes"]),
            LabTreeDatabase(id: "pg18.postgres", name: "postgres", tables: ["pg_stat_statements"]),
        ],
        "tippr": [
            LabTreeDatabase(id: "tippr.rundeck", name: "rundeck", tables: ["job_runs", "jobs", "nodes"]),
            LabTreeDatabase(id: "tippr.tippr", name: "tippr", tables: ["users", "tips", "payouts", "sessions"]),
        ],
        "pg16": [
            LabTreeDatabase(id: "pg16.analytics", name: "analytics", tables: ["events", "pageviews", "sessions"]),
        ],
    ]
}

/// The window canvas behind rail, tree and cards.
enum LabCanvas: String, CaseIterable, Identifiable {
    case grey = "System grey"
    case translucent = "Translucent"
    var id: String { rawValue }
}

struct LabCanvasBackground: View {
    let canvas: LabCanvas

    var body: some View {
        switch canvas {
        case .grey:
            Color(nsColor: .windowBackgroundColor)
        case .translucent:
            // Stand-in for a behind-window blur: a colourful "desktop" under a thick material.
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.5), .purple.opacity(0.35), .orange.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(.regularMaterial)
            }
        }
    }
}

/// A content card (editor, results): opaque, as Apple's guidance keeps glass off content.
struct LabCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var shadow: LabCardShadow = .lift
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.separator.opacity(shadow == .hairline ? 0.8 : 0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(shadow == .lift ? 0.12 : 0.05), radius: shadow == .lift ? 10 : 1, y: shadow == .lift ? 4 : 0.5)
    }
}

enum LabCardShadow: String, CaseIterable, Identifiable {
    case lift = "Floating shadow"
    case hairline = "Hairline"
    var id: String { rawValue }
}

/// Placeholder SQL text for editor cards.
struct LabEditorText: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SELECT emp_no, salary, from_date").foregroundStyle(.primary)
            Text("FROM employees.salary").foregroundStyle(.primary)
            Text("WHERE to_date > now()").foregroundStyle(.secondary)
            Text("ORDER BY salary DESC").foregroundStyle(.secondary)
            Text("LIMIT 50;").foregroundStyle(.secondary)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(14)
    }
}

/// A plain tree row used by the lab's mock Explorer.
struct LabTreeRow: View {
    let depth: Int
    let icon: String
    let title: String
    var detail: String? = nil
    var isExpanded: Bool? = nil
    var iconColor: Color = .secondary
    var isSelected = false

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded == true ? 90 : 0))
                .opacity(isExpanded == nil ? 0 : 1)
                .frame(width: 10)
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(title).font(.system(size: 12)).lineLimit(1)
            Spacer(minLength: 4)
            if let detail {
                Text(detail).font(.system(size: 11)).monospacedDigit().foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 6 + CGFloat(depth) * 12)
        .padding(.trailing, 8)
        .frame(height: 24)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.1) : isHovering ? Color.primary.opacity(0.05) : .clear)
        }
        .onHover { isHovering = $0 }
    }
}

/// Labelled segmented picker used in lab control bars.
struct LabPicker<Value: Hashable & Identifiable & RawRepresentable>: View where Value.RawValue == String {
    let title: String
    @Binding var selection: Value
    let options: [Value]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
}

/// Wraps a lab stage with a control bar on top.
struct LabStage<Controls: View, Content: View>: View {
    let title: String
    @ViewBuilder var controls: () -> Controls
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                HStack(spacing: 14) { controls() }
                    .controlSize(.small)
            }
            .padding(12)
            Divider()
            content()
        }
    }
}
