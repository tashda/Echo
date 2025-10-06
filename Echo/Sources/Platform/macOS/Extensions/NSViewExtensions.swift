//
//  NSViewExtensions.swift
//  Echo
//
//  Created by Codex on 07/10/2025.
//
//  Portions of this file are adapted from Ghostty (https://github.com/mitchellh/ghostty)
//  and retain the original MIT license:
//
//  MIT License
//  Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import AppKit
import SwiftUI

extension NSView {
    /// Returns the absolute root view by walking up the superview chain.
    var rootView: NSView {
        var root: NSView = self
        while let superview = root.superview {
            root = superview
        }
        return root
    }

    /// Checks if a view contains another view in its hierarchy.
    func contains(_ view: NSView) -> Bool {
        if self == view {
            return true
        }

        for subview in subviews where subview.contains(view) {
            return true
        }

        return false
    }

    /// Checks if the view contains the given class in its hierarchy.
    func contains(className name: String) -> Bool {
        if String(describing: type(of: self)) == name {
            return true
        }

        for subview in subviews where subview.contains(className: name) {
            return true
        }

        return false
    }

    /// Finds the superview with the given class name.
    func firstSuperview(withClassName name: String) -> NSView? {
        guard let superview else { return nil }
        if String(describing: type(of: superview)) == name {
            return superview
        }

        return superview.firstSuperview(withClassName: name)
    }

    /// Recursively finds and returns the first descendant view that has the given class name.
    func firstDescendant(withClassName name: String) -> NSView? {
        for subview in subviews {
            if String(describing: type(of: subview)) == name {
                return subview
            }

            if let found = subview.firstDescendant(withClassName: name) {
                return found
            }
        }

        return nil
    }

    /// Recursively finds and returns descendant views that have the given class name.
    func descendants(withClassName name: String) -> [NSView] {
        var result: [NSView] = []

        for subview in subviews {
            if String(describing: type(of: subview)) == name {
                result.append(subview)
            }

            result += subview.descendants(withClassName: name)
        }

        return result
    }

    /// Recursively finds and returns the first descendant view that has the given identifier.
    func firstDescendant(withID id: String) -> NSView? {
        for subview in subviews {
            if subview.identifier == NSUserInterfaceItemIdentifier(id) {
                return subview
            }

            if let found = subview.firstDescendant(withID: id) {
                return found
            }
        }

        return nil
    }

    /// Finds and returns the first view with the given class name starting from the absolute root of the view hierarchy.
    /// This includes private views like title bar views.
    func firstViewFromRoot(withClassName name: String) -> NSView? {
        let root = rootView

        if String(describing: type(of: root)) == name {
            return root
        }

        return root.firstDescendant(withClassName: name)
    }
}
