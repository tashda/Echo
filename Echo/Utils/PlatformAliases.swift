// PlatformAliases.swift

#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
typealias PlatformEvent = NSEvent
#else
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
typealias PlatformEvent = UIEvent
#endif
