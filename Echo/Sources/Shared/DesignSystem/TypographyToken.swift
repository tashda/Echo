import SwiftUI

public enum TypographyTokens {
    public enum Weight {
        public static let regular = SwiftUI.Font.Weight.regular
        public static let medium = SwiftUI.Font.Weight.medium
        public static let semibold = SwiftUI.Font.Weight.semibold
        public static let bold = SwiftUI.Font.Weight.bold
    }

    // Semantic styles (dynamic type)
    public static let title = SwiftUI.Font.system(.title, design: .default)
    public static let title2 = SwiftUI.Font.system(.title2, design: .default)
    public static let title3 = SwiftUI.Font.system(.title3, design: .default)
    public static let headline = SwiftUI.Font.system(.headline, design: .default)
    public static let subheadline = SwiftUI.Font.system(.subheadline, design: .default)
    public static let body = SwiftUI.Font.system(.body, design: .default)
    public static let callout = SwiftUI.Font.system(.callout, design: .default)
    public static let caption = SwiftUI.Font.system(.caption, design: .default)
    public static let footnote = SwiftUI.Font.system(.footnote, design: .default)
    public static let monospaced = SwiftUI.Font.system(.body, design: .monospaced)

    // Fixed-size styles for macOS UI where precise sizing matters
    /// 9pt — toolbar badges, compact indicators
    public static let compact = SwiftUI.Font.system(size: 9)
    /// 10pt — sidebar counts, small labels
    public static let label = SwiftUI.Font.system(size: 10)
    /// 11pt — table cells, footnotes, secondary detail
    public static let detail = SwiftUI.Font.system(size: 11)
    /// 12pt — secondary labels, form fields
    public static let caption2 = SwiftUI.Font.system(size: 12)
    /// 13pt Regular — primary UI text, body equivalent
    public static let standard = SwiftUI.Font.system(size: 13)
    /// 14pt — section headers, prominent labels
    public static let prominent = SwiftUI.Font.system(size: 14)
    
    // Tahoe Form Styles
    /// 13pt Bold — Form section headers matching System Settings (e.g. "Windows")
    public static let formSectionTitle = SwiftUI.Font.system(size: 13).weight(.bold)
    /// 13pt Regular — Primary label text in form rows
    public static let formLabel = SwiftUI.Font.system(size: 13)
    /// 13pt Regular — Primary value text in form rows (e.g. selected item in a Pop-up button)
    public static let formValue = SwiftUI.Font.system(size: 13)
    /// 11pt Regular — Secondary description or subtitle text in form rows
    public static let formDescription = SwiftUI.Font.system(size: 11)

    /// 12pt Bold — Legacy Form section headers (consider migrating to formSectionTitle)
    public static let formSectionHeader = SwiftUI.Font.system(size: 12).weight(.bold)

    /// 12pt Medium — Status badges and indicators
    public static let statusLabel = SwiftUI.Font.system(size: 12).weight(.medium)

    // MARK: - Table Cell Roles
    // Semantic tokens for SwiftUI Table columns. Change here to update every table at once.

    public enum Table {
        /// Primary name / identifier columns (Index, Table, User, Database).
        /// Uses table default size — do not set an explicit font on these columns
        /// unless you need to opt out. This token exists for the rare case where
        /// you must pass a Font value; prefer omitting .font() entirely.
        public static let name = TypographyTokens.standard

        /// Type / category labels (e.g. "clustered index", "TASK MANAGER", lock mode).
        public static let category = TypographyTokens.statusLabel

        /// Numeric values (counts, sizes, durations, IDs).
        public static let numeric = TypographyTokens.monospaced

        /// Percentages and ratios.
        public static let percentage = TypographyTokens.statusLabel

        /// Date and time values (intentionally smaller / de-emphasised).
        public static let date = TypographyTokens.detail

        /// Status text (Healthy, Fragmented, Running, Sleeping …).
        public static let status = TypographyTokens.statusLabel

        /// Tiny kind / tag badges (PK, UQ, IX).
        public static let kindBadge = TypographyTokens.compact.weight(.bold)

        /// Supporting identifier columns (owner, schema, app name, client address).
        /// Same size as `name` but always paired with `.secondary` / `.tertiary` color.
        public static let secondaryName = TypographyTokens.standard

        /// File paths, device paths, LSNs, and other technical strings.
        /// 11pt monospaced — de-emphasised like dates but monospaced for readability.
        public static let path = SwiftUI.Font.system(size: 11, design: .monospaced)

        /// Inline SQL preview text in table cells.
        /// 11pt monospaced — same base as `path` today, separate token for future divergence.
        public static let sql = SwiftUI.Font.system(size: 11, design: .monospaced)
    }

    /// 16pt — large headers
    public static let display = SwiftUI.Font.system(size: 16)
    /// 18pt — large display headers
    public static let displayLarge = SwiftUI.Font.system(size: 18)
    /// 20pt+ — hero text, large icons
    public static let hero = SwiftUI.Font.system(size: 20)
}
