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

    // Explorer / Object Browser
    public enum Explorer {
        public static let database = Color(red: 0.18, green: 0.66, blue: 0.30)
        public static let tables = Color(red: 0.22, green: 0.56, blue: 0.73)
        public static let views = Color(red: 0.36, green: 0.38, blue: 0.92)
        public static let functions = Color(red: 0.83, green: 0.53, blue: 0.05)
        public static let jobs = Color(red: 0.06, green: 0.48, blue: 0.98)
        public static let security = Color(red: 0.38, green: 0.45, blue: 0.65)
        public static let extensions = Color(red: 0.84, green: 0.52, blue: 0.00)
    }
}
