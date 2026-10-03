import SwiftUI
import StageKit
import StageCore

/// The sizes one toast is drawn with. Echo today and Option A are fixed; Option B (and every Mix) reads the controls.
struct ToastMetrics: Equatable {
    var pad: Double
    var gap: Double
    var icon: Double
    var fontSize: Double

    /// Echo today, as built now.
    static let today = ToastMetrics(pad: 10, gap: 8, icon: 20, fontSize: 12)
    /// Option A, quiet.
    static let optionA = ToastMetrics(pad: 12, gap: 10, icon: 22, fontSize: 12.5)

    static func roomy(controls: [String: String]) -> ToastMetrics {
        let pad: Double
        switch controls["padding"] ?? "p12" {
        case "p16": pad = 16
        case "p20": pad = 20
        default: pad = 12
        }
        let icon: Double
        switch controls["icon"] ?? "medium" {
        case "small": icon = 22
        case "large": icon = 34
        default: icon = 28
        }
        return ToastMetrics(pad: pad, gap: (pad * 0.85).rounded(), icon: icon, fontSize: 13)
    }

    static func forSpecimen(_ id: String, controls: [String: String]) -> ToastMetrics {
        switch id {
        case "today": return .today
        case "a": return .optionA
        default: return roomy(controls: controls)
        }
    }
}

/// One toast's words in a scenario.
struct ToastContent {
    var title: String
    var detail: String
    var isError: Bool
    var showsActions: Bool
    var showsClose: Bool
    var actionTitle: String
    var lines: Int
    var extraToasts: [(String, String)]

    static func forScenario(_ scenario: String) -> ToastContent {
        switch scenario {
        case "hover":
            return ToastContent(title: "Connection restored", detail: "Prod-EU is reachable again.", isError: false,
                                showsActions: true, showsClose: true, actionTitle: "View", lines: 2, extraToasts: [])
        case "error":
            return ToastContent(title: "Query failed", detail: "Timed out after 30 s.", isError: true,
                                showsActions: true, showsClose: false, actionTitle: "Retry", lines: 2, extraToasts: [])
        case "long-text":
            return ToastContent(title: "Export finished",
                                detail: "4,812 rows written to \"Quarterly revenue by region and product line.csv\" in your Downloads folder.",
                                isError: false, showsActions: false, showsClose: false, actionTitle: "View", lines: 3, extraToasts: [])
        case "many-items":
            return ToastContent(title: "Connection restored", detail: "Prod-EU is reachable again.", isError: false,
                                showsActions: false, showsClose: false, actionTitle: "View", lines: 2,
                                extraToasts: [("Backup saved", "Prod-EU at 12:04."), ("Sync complete", "3 changes pulled.")])
        default:
            return ToastContent(title: "Connection restored", detail: "Prod-EU is reachable again.", isError: false,
                                showsActions: false, showsClose: false, actionTitle: "View", lines: 2, extraToasts: [])
        }
    }
}

/// The round's specimens: Echo today and two options of the notification toast, as plain SwiftUI with sample data.
@MainActor
final class ToastProvider: SpecimenProvider {
    static let cardDesignSize = CGSize(width: 300, height: 240)
    static let toastWidth: Double = 250
    static let topInset: Double = 14

    func specimenView(id: String, scenario: String, controls: [String: String]) -> AnyView {
        AnyView(ToastSpecimen(metrics: ToastMetrics.forSpecimen(id, controls: controls),
                              content: ToastContent.forScenario(scenario),
                              timeout: Self.timeout(controls)))
    }

    func designSize(for id: String) -> CGSize { Self.cardDesignSize }

    func hasSpecimen(id: String) -> Bool { id == "today" || id == "a" || id == "b" }

    // MARK: Sizes (Matrix and Redlines)

    /// Height of the first toast, as the prototype estimated it.
    static func firstToastHeight(_ m: ToastMetrics, _ c: ToastContent) -> Double {
        let text = Double(c.lines) * (m.fontSize + 3)
        let actions: Double = c.showsActions ? 20 : 0
        return 2 * m.pad + max(m.icon, text) + actions
    }

    func measuredHeight(id: String, scenario: String, controls: [String: String]) -> Double? {
        let m = ToastMetrics.forSpecimen(id, controls: controls)
        let c = ToastContent.forScenario(scenario)
        var h = Self.firstToastHeight(m, c)
        for _ in c.extraToasts { h += 2 * m.pad + m.fontSize * 2 + 8 }
        return h
    }

    func redlines(id: String, scenario: String, controls: [String: String]) -> [StageRedline] {
        let m = ToastMetrics.forSpecimen(id, controls: controls)
        let c = ToastContent.forScenario(scenario)
        let left = (Self.cardDesignSize.width - Self.toastWidth) / 2
        let top = Self.topInset
        let h = Self.firstToastHeight(m, c)
        let pad = StageRedline(id: "pad", kind: .padding, x: left + m.pad, y: top + m.pad,
                               width: Self.toastWidth - 2 * m.pad, height: h - 2 * m.pad, label: "\(Int(m.pad))")
        let icon = StageRedline(id: "icon", kind: .size, x: left + m.pad, y: top + m.pad, width: m.icon, height: m.icon,
                                label: "\(Int(m.icon))")
        let gap = StageRedline(id: "gap", kind: .gap, x: left + m.pad + m.icon, y: top + m.pad + m.icon / 2 - 3,
                               width: m.gap, height: 6, label: "\(Int(m.gap))")
        return [pad, icon, gap]
    }

    // MARK: Motion

    static func timeout(_ controls: [String: String]) -> Double {
        Double(controls["timeout"] ?? "4") ?? 4
    }

    func motionDuration(id: String, scenario: String, controls: [String: String]) -> Double? {
        Self.timeout(controls) + 0.8
    }

    func motionMarks(id: String, scenario: String, controls: [String: String]) -> [StageMotionMark] {
        let t = Self.timeout(controls)
        return [
            StageMotionMark(id: "card", label: "toast.card", start: 0, end: t + ToastMotion.exitSeconds),
            StageMotionMark(id: "close", label: "toast.close", start: ToastMotion.enterSeconds, end: t),
        ]
    }
}

/// The whole specimen: one toast, or three stacked for "Many items".
struct ToastSpecimen: View {
    let metrics: ToastMetrics
    let content: ToastContent
    let timeout: Double

    var body: some View {
        VStack(spacing: 8) {
            ToastCard(metrics: metrics, title: content.title, detail: content.detail, isError: content.isError,
                      showsActions: content.showsActions, showsClose: content.showsClose, actionTitle: content.actionTitle)
            ForEach(content.extraToasts.indices, id: \.self) { i in
                ToastCard(metrics: metrics, title: content.extraToasts[i].0, detail: content.extraToasts[i].1, isError: false,
                          showsActions: false, showsClose: false, actionTitle: "View")
            }
        }
        .padding(.top, CGFloat(ToastProvider.topInset))
        .modifier(ToastMotion(timeout: timeout))
    }
}

/// Appear and go away on the transport bar's clock. Without the transport the toast simply rests.
struct ToastMotion: ViewModifier {
    static let enterSeconds: Double = 0.35
    static let exitSeconds: Double = 0.3

    let timeout: Double
    @Environment(\.stageTransportTime) private var time
    @Environment(\.stageReduceMotion) private var reduceMotion

    /// Opacity and vertical offset at a time. Reduce Motion fades without sliding.
    static func frame(time: Double?, timeout: Double, reduceMotion: Bool) -> (opacity: Double, offset: Double) {
        guard let t = time else { return (1, 0) }
        if t < enterSeconds {
            let p = max(t, 0) / enterSeconds
            return (p, reduceMotion ? 0 : (1 - p) * -24)
        }
        if t <= timeout { return (1, 0) }
        let q = min((t - timeout) / exitSeconds, 1)
        return (1 - q, reduceMotion ? 0 : q * -12)
    }

    func body(content: Content) -> some View {
        let f = ToastMotion.frame(time: time, timeout: timeout, reduceMotion: reduceMotion)
        return content
            .opacity(f.opacity)
            .offset(y: CGFloat(f.offset))
    }
}

/// One toast card. Colours and corners come from the Stage's environment, not from the system.
struct ToastCard: View {
    let metrics: ToastMetrics
    let title: String
    let detail: String
    let isError: Bool
    let showsActions: Bool
    let showsClose: Bool
    let actionTitle: String

    @Environment(\.stagePalette) private var palette
    @Environment(\.stageCornerRadius) private var radius
    @Environment(\.stageTextScale) private var textScale

    private var fontSize: CGFloat { CGFloat(metrics.fontSize) * textScale }

    var body: some View {
        HStack(alignment: .top, spacing: CGFloat(metrics.gap)) {
            Circle()
                .fill(isError ? palette.error : palette.accent)
                .frame(width: CGFloat(metrics.icon), height: CGFloat(metrics.icon))
            textColumn
            Spacer(minLength: 0)
            if showsClose {
                Text("✕")
                    .font(.system(size: 11 * textScale))
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(CGFloat(metrics.pad))
        .frame(width: CGFloat(ToastProvider.toastWidth), alignment: .leading)
        .background(RoundedRectangle(cornerRadius: radius).fill(palette.card))
        .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(palette.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.12), radius: 7, x: 0, y: 4)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(detail)
                .font(.system(size: fontSize))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            if showsActions {
                HStack(spacing: 8) {
                    Text(actionTitle)
                    Text("Dismiss")
                }
                .font(.system(size: fontSize - 1, weight: .semibold))
                .foregroundStyle(palette.accent)
                .padding(.top, 4)
            }
        }
    }
}
