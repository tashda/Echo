import Observation
import SwiftUI

/// Settings the Explorer tree specimen shares with its controls.
@Observable @MainActor
final class ExplorerTreeSpecimenSettings {
    var iconMode: LabDockIconMode = LabPrefs.load("explorerTree.iconMode", default: LabDockIconMode.duotone) {
        didSet { LabPrefs.save(iconMode, key: "explorerTree.iconMode") }
    }
}

/// The Explorer tree as it is in Echo today: server cards with S4 Quiet rows, duotone icons and
/// the section dock (decisions 2026-09-29 and 2026-09-30; plan D1, D2).
@MainActor
enum ExplorerTreeArea {
    private static let settings = ExplorerTreeSpecimenSettings()

    static let area = LabArea(
        id: "explorer-tree",
        title: "Explorer tree",
        symbol: "list.bullet.indent",
        summary: "Each server sits on its own card: quiet 28pt rows, duotone icons, and a dock of section icons pinned under the server's name.",
        asBuilt: AsBuiltPage(
            verification: .init(
                level: .code, commit: "a24192df", date: "2026-09-30",
                note: "The specimen is the Round 14 dock card; measurements are read from SidebarRowConstants and the decision log."),
            stageHeight: 540,
            behaviours: [
                .init(trigger: "Hover a row", result: "A folder's icon turns into a chevron and its count appears. Nothing else moves."),
                .init(trigger: "Click a folder", result: "It opens or closes; the rows below slide and fade, like the native outline."),
                .init(trigger: "Click an object", result: "Grey selection fill with the row's icon in its accent."),
                .init(trigger: "Click a dock icon", result: "The card shows that section. Each section keeps its scroll position and its open folders."),
                .init(trigger: "Scroll the rows", result: "Rows pass under the pinned dock, which has only a soft blur: no background and no line."),
                .init(trigger: "Right-click", result: "A menu for that node kind, from the database type's blueprint."),
                .init(trigger: "Schema prefix", result: "Dimmed on tables outside the default schema."),
            ],
            motions: [
                .init(name: "Folder open and close", curve: "ease in-out", duration: "0.22s", note: "echoMotion.expand"),
                .init(name: "Reveal in the tree", curve: "smooth", duration: "0.40s", note: "echoMotion.reveal, scrolling to a picked object"),
                .init(name: "Hover fill", curve: "ease out", duration: "0.12s", note: "echoMotion.hover"),
                .init(name: "Switch dock section", curve: "house spring, bounce 0.08", duration: "0.45s", note: "echoMotion.standard; 8pt slide and fade"),
            ],
            measurements: [
                .init(label: "Row height", value: "28pt in a 29pt slot", token: "medium density"),
                .init(label: "Icon frame", value: "18 × 16pt", token: "SidebarRowConstants.iconFrameWidth / Height"),
                .init(label: "Icon to label", value: "8pt", token: "SidebarRowConstants.iconTextSpacing"),
                .init(label: "Indent per level", value: "16pt", token: "SidebarRowConstants.indentStep"),
                .init(label: "Row padding", value: "6pt leading · 8pt trailing", token: "rowLeadingPadding / rowTrailingPadding"),
                .init(label: "Row corner", value: "8pt", token: "LayoutTokens.Workspace.treeRowCornerRadius"),
                .init(label: "Server name", value: "Bold 13pt", token: "SidebarRowConstants.serverHeaderFont"),
                .init(label: "Folder chevron", value: "Semibold 11pt", token: "SidebarRowConstants.chevronFont"),
                .init(label: "Row label", value: "13pt at the default density", token: "scales with the density setting"),
                .init(label: "Card corners", value: "16pt (setting: 10 to 26)", token: "LayoutTokens.Workspace.cardCornerRadius"),
                .init(label: "Card edge", value: "0.5pt at 35% separator", token: "cardEdgeWidth / cardEdgeOpacity"),
                .init(label: "Icons", value: "Duotone by default; mono line is a setting", token: "IC2 / IC1"),
            ],
            rules: [
                .init(text: "Every server has its own opaque card",
                      why: "The tree is content, so it follows the editor card's tokens; glass is only for controls.",
                      rounds: ["decided.window-canvas-and-cards"]),
                .init(text: "S4 Quiet rows",
                      why: "No chevron column, light symbols and roomy rows read like Finder and Linear. Tahoe, Tiles, Structure, Detailed and Path were rejected.",
                      rounds: ["decided.tree-card-s4-quiet"]),
                .init(text: "A dock of icons under the server's name",
                      why: "It switches sections without long scrolling and remembers each one's place. Every other layout (TC2 to TC9) was rejected.",
                      rounds: ["ported.Round 14 · section dock"]),
                .init(text: "Duotone icons by default",
                      why: "Tiles, letters and dots were rejected; a Recraft icon set is planned, with SF Symbols drawn duotone until then.",
                      rounds: ["ported.Round 14 · section dock"]),
                .init(text: "No pinned path header",
                      why: "It cost space and added blur; the dock does the job of orientation.",
                      rounds: ["decided.tree-sticky-header"]),
            ],
            code: [
                "Echo/Sources/Features/ObjectBrowser/Blueprint/ExplorerBlueprint+*.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerRowModels.swift",
                "Echo/Sources/Features/ObjectBrowser/Views/Components/ExplorerDock.swift",
                "Echo/Sources/Shared/DesignSystem/Components/SidebarRow.swift",
            ]
        ) {
            ExplorerTreeSpecimen(settings: settings)
        }
        .controls {
            ExplorerTreeControls(settings: settings)
        }
    )
}

private struct ExplorerTreeSpecimen: View {
    let settings: ExplorerTreeSpecimenSettings
    @Environment(\.echoMotion) private var motion

    var body: some View {
        LabRound14DockCard(iconMode: settings.iconMode, labels: .iconsOnly, edge: .soft, animation: motion.standard)
    }
}

private struct ExplorerTreeControls: View {
    @Bindable var settings: ExplorerTreeSpecimenSettings

    var body: some View {
        HStack {
            Picker("Icons", selection: $settings.iconMode) {
                Text("Duotone (default)").tag(LabDockIconMode.duotone)
                Text("Mono line (setting)").tag(LabDockIconMode.mono)
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            Spacer()
        }
    }
}
