import Foundation

// Performance optimization settings for PostgreSQL queries
// Run this script to apply optimal settings for large result sets

func setPerformanceDefaults() {
    let defaults = UserDefaults.standard

    // 🚀 OPTIMAL SETTINGS FOR LARGE QUERIES (100k+ rows)

    // Larger fetch sizes for better throughput
    defaults.set(8192, forKey: "dk.tippr.echo.streaming.fetchSize")

    // Aggressive ramping for large datasets
    defaults.set(3, forKey: "dk.tippr.echo.streaming.fetchRampMultiplier")
    defaults.set(32768, forKey: "dk.tippr.echo.streaming.fetchRampMax")

    // Use cursor mode for large queries (keep current auto mode logic)
    // defaults.set(false, forKey: "dk.tippr.echo.streaming.useCursor")

    // Lower cursor threshold to prefer cursor mode for large queries
    defaults.set(10000, forKey: "dk.tippr.echo.streaming.cursorThreshold")

    // Enable deferred formatting for better initial responsiveness
    defaults.set(true, forKey: "dk.tippr.echo.results.formattingEnabled")
    defaults.set("deferred", forKey: "dk.tippr.echo.results.formattingMode")

    print("✅ Performance settings applied!")
    print("📊 Fetch size: 8192 rows")
    print("📈 Ramp multiplier: 3x")
    print("🎯 Max fetch size: 32768 rows")
    print("🔄 Cursor threshold: 10,000 rows")
    print("⚡ Formatting: Deferred mode")
    print("")
    print("🚀 Restart your app to apply these settings.")
}

func showCurrentSettings() {
    let defaults = UserDefaults.standard

    let fetchSize = defaults.integer(forKey: "dk.tippr.echo.streaming.fetchSize")
    let rampMultiplier = defaults.integer(forKey: "dk.tippr.echo.streaming.fetchRampMultiplier")
    let rampMax = defaults.integer(forKey: "dk.tippr.echo.streaming.fetchRampMax")
    let cursorThreshold = defaults.integer(forKey: "dk.tippr.echo.streaming.cursorThreshold")
    let useCursor = defaults.bool(forKey: "dk.tippr.echo.streaming.useCursor")
    let formattingEnabled = defaults.bool(forKey: "dk.tippr.echo.results.formattingEnabled")
    let formattingMode = defaults.string(forKey: "dk.tippr.echo.results.formattingMode") ?? "immediate"

    print("📊 Current PostgreSQL Performance Settings:")
    print("   Fetch size: \(fetchSize == 0 ? "4096 (default)" : "\(fetchSize)") rows")
    print("   Ramp multiplier: \(rampMultiplier == 0 ? "1 (default)" : "\(rampMultiplier)")x")
    print("   Max fetch size: \(rampMax == 0 ? "256 (default)" : "\(rampMax)") rows")
    print("   Cursor threshold: \(cursorThreshold == 0 ? "25000 (default)" : "\(cursorThreshold)") rows")
    print("   Force cursor mode: \(useCursor ? "Yes" : "No (auto)")")
    print("   Formatting enabled: \(formattingEnabled ? "Yes" : "No")")
    print("   Formatting mode: \(formattingMode)")
}

print("🔧 PostgreSQL Performance Settings Tool")
print("")

if CommandLine.arguments.count > 1 && CommandLine.arguments[1] == "apply" {
    setPerformanceDefaults()
} else {
    showCurrentSettings()
    print("")
    print("💡 Run 'swift Scripts/performance/performance_settings.swift apply' to apply optimal settings")
}
