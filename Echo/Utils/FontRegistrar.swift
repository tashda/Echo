import Foundation
import CoreText
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Registers bundled custom fonts so they are available throughout the app
enum FontRegistrar {
    private static let fontSubdirectory = "Fonts"

    static func registerBundledFonts() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: fontSubdirectory) else {
            return
        }

        for url in urls {
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !success {
                if let cfError = error?.takeRetainedValue() {
                    print("[FontRegistrar] Failed to register font at \(url.lastPathComponent): \(cfError)")
                }
            }
        }
    }
}
