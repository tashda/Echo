import SwiftUI

public enum ColorTokens {
    // Brand / App Accent
    public static let accent = Color.accentColor
    
    // Backgrounds
    public enum Background {
        public static let primary = Color(nsColor: .windowBackgroundColor)
        public static let secondary = Color(nsColor: .controlBackgroundColor)
        public static let tertiary = Color(nsColor: .textBackgroundColor)
        public static let elevated = Color(nsColor: .underPageBackgroundColor)
    }
    
    // Text
    public enum Text {
        public static let primary = Color.primary
        public static let secondary = Color.secondary
        public static let tertiary = Color(nsColor: .tertiaryLabelColor)
        public static let quaternary = Color(nsColor: .quaternaryLabelColor)
        public static let placeholder = Color(nsColor: .placeholderTextColor)
    }
    
    // Dividers / Borders
    public enum Separator {
        public static let primary = Color(nsColor: .separatorColor)
        public static let secondary = Color(nsColor: .gridColor)
    }
    
    // Status
    public enum Status {
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue
    }
}
