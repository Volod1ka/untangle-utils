// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import CoreGraphics
import Foundation

/// The decisions behind the language badge shown when a text field takes the
/// focus: which elements are text fields, when focus really moved, and where
/// the badge goes. Plain values only, so they stay testable.
///
/// Geometry is in Accessibility's screen space: origin at the top-left of the
/// primary display, y growing down.
enum FocusLanguageBadgeSupport {
    /// Roles that take typed text. Secure and search fields are subroles of a
    /// text field, so its role covers them; a password field is exactly
    /// where typing in the wrong language hurts most.
    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]

    static func isTextInput(role: String?) -> Bool {
        guard let role else { return false }
        return textRoles.contains(role)
    }

    /// An app that names a whole window as its focused element keeps its
    /// content to itself until an assistive app switches it into assistive
    /// mode: Firefox, and Chromium browsers, do this with web pages. Plain
    /// apps name the window too when nothing in it has the focus, so this
    /// alone is never enough; see `embedsWebEngine`.
    static func hidesItsContent(focusedRole: String?) -> Bool {
        focusedRole == "AXWindow"
    }

    /// Whether an app bundle carries a web engine that describes its pages
    /// only on request, read from what the bundle holds rather than from a
    /// list of names: Gecko (Firefox and its kin) ships `XUL` beside the
    /// executable, Electron and embedded Chromium ship their framework by
    /// name or renderer helpers, and Chromium browsers ship a
    /// "<Product> Framework" that holds the helpers.
    static func embedsWebEngine(executables: [String], frameworks: [String],
                                frameworkHasHelpers: (String) -> Bool) -> Bool {
        if executables.contains("XUL") { return true }
        return frameworks.contains { name in
            name == "Electron Framework.framework"
                || name == "Chromium Embedded Framework.framework"
                || name.hasSuffix(" Helper (Renderer).app")
                || (name.hasSuffix(" Framework.framework") && frameworkHasHelpers(name))
        }
    }

    /// One app this feature switched into an assistive mode, written down so
    /// a run that ends without cleaning up (a crash, a force quit) can be
    /// undone by the next one. The launch time tells the app apart from a
    /// later process given the same pid.
    struct AssistedApp: Equatable {
        enum Mode: String {
            /// `AXEnhancedUserInterface`, what VoiceOver sets.
            case enhanced
            /// `AXManualAccessibility`, Electron's own.
            case manual
        }

        let pid: Int32
        let launched: Double
        let mode: Mode

        var stored: [String: Any] { ["pid": Int(pid), "launched": launched, "mode": mode.rawValue] }

        init(pid: Int32, launched: Double, mode: Mode) {
            self.pid = pid
            self.launched = launched
            self.mode = mode
        }

        init?(stored: [String: Any]) {
            guard let pid = stored["pid"] as? Int, let launched = stored["launched"] as? Double,
                  let mode = (stored["mode"] as? String).flatMap(Mode.init(rawValue:)) else { return nil }
            self.init(pid: Int32(pid), launched: launched, mode: mode)
        }

        /// The same process when its launch time matches, to within the
        /// rounding a stored time picks up.
        func isSameProcess(launchedAt time: Double?) -> Bool {
            guard let time else { return false }
            return abs(time - launched) < 1
        }
    }

    /// Remembers the element that had the focus last, so the badge shows when
    /// focus arrives in a field and not again for every click inside it.
    struct FocusMemory<Key: Equatable> {
        private var last: Key?

        /// Whether a move of the focus to `key` should show the badge.
        mutating func focusMoved(to key: Key?, isTextInput: Bool) -> Bool {
            defer { last = key }
            guard isTextInput, let key else { return false }
            return key != last
        }

        mutating func reset() { last = nil }
    }

    /// A caret taller than this is a whole text view reporting its bounds,
    /// not the insertion point.
    static let maximumCaretHeight: CGFloat = 120
    /// A field up to this tall is one line, so its own frame says where the
    /// text is. In a taller text view the caret can be anywhere.
    static let singleLineHeight: CGFloat = 48

    /// Where the badge hangs from, and what that place was taken from.
    struct Anchor: Equatable {
        enum Source: String {
            /// The insertion point, as the app measured it: where macOS's
            /// own indicator goes.
            case caret
            /// The caret's x, put back inside its field: the app measured
            /// the caret off its own field (Telegram reports it one caret
            /// height too high).
            case correctedCaret
            /// A one-line field whose app did not say where its caret is.
            case field
        }

        let rect: CGRect
        let source: Source
    }

    /// The rect the badge hangs under, the way macOS places its own language
    /// indicator: the caret when the app reports a usable one, else a
    /// one-line field. Never the mouse pointer, which can be anywhere. Nil
    /// when nothing says where the caret is, such as a terminal that does not
    /// measure its text, so the badge never lands somewhere unrelated.
    static func anchor(caret: CGRect?, field: CGRect?) -> Anchor? {
        let field = field.flatMap { $0.width > 0 && $0.height > 0 ? $0 : nil }
        // Apps without a caret answer with a zero rect at the origin.
        if let caret, caret.height > 0, caret.height <= maximumCaretHeight, caret.origin != .zero {
            guard let field else { return Anchor(rect: caret, source: .caret) }
            let inside = field.insetBy(dx: -caretTolerance, dy: -caretTolerance)
            let alongField = caret.minX >= inside.minX && caret.minX <= inside.maxX
            if alongField, caret.minY >= inside.minY, caret.maxY <= inside.maxY {
                return Anchor(rect: caret, source: .caret)
            }
            // Its x along the field is still the best guess at where the
            // text is; a caret far off to the side is no guess at all.
            if alongField, abs(caret.midY - field.midY) <= field.height / 2 + caret.height * 2 {
                let height = min(caret.height, field.height)
                let y = field.height <= singleLineHeight
                    ? field.midY - height / 2
                    : min(max(caret.minY, field.minY), field.maxY - height)
                return Anchor(rect: CGRect(x: caret.minX, y: y, width: 0, height: height),
                              source: .correctedCaret)
            }
        }
        guard let field, field.height <= singleLineHeight else { return nil }
        return Anchor(rect: field, source: .field)
    }

    /// How far a caret may stick out of its field and still count as measured
    /// right: rounding, and the field's border.
    static let caretTolerance: CGFloat = 3

    /// The caret from what the app measured. Many text views answer an empty
    /// range with nothing, so the character before the caret (its right
    /// edge) or the one after it (its left edge) stands in.
    static func caret(collapsed: CGRect?, before: CGRect?, after: CGRect?) -> CGRect? {
        func usable(_ rect: CGRect?) -> CGRect? {
            guard let rect, rect.height > 0, rect.origin != .zero else { return nil }
            return rect
        }
        if let collapsed = usable(collapsed) { return collapsed }
        if let before = usable(before) {
            return CGRect(x: before.maxX, y: before.minY, width: 0, height: before.height)
        }
        if let after = usable(after) {
            return CGRect(x: after.minX, y: after.minY, width: 0, height: after.height)
        }
        return nil
    }

    static let gap: CGFloat = 4

    /// The badge's top-left corner: under the anchor, or over it when the
    /// screen ends below, and always inside the screen the anchor is on.
    static func origin(for size: CGSize, under anchor: CGRect, screens: [CGRect]) -> CGPoint {
        let center = CGPoint(x: anchor.midX, y: anchor.midY)
        let screen = screens.first { $0.contains(center) }
            ?? screens.first { $0.intersects(anchor) }
            ?? screens.first
            ?? .infinite
        var y = anchor.maxY + gap
        if y + size.height > screen.maxY {
            y = anchor.minY - gap - size.height
        }
        var x = anchor.minX
        if !screen.isInfinite {
            x = min(max(x, screen.minX), screen.maxX - size.width)
            y = min(max(y, screen.minY), screen.maxY - size.height)
        }
        return CGPoint(x: x, y: y)
    }

    /// Converts a rect between Accessibility's top-left space and AppKit's
    /// bottom-left one; the conversion is its own inverse.
    static func flipped(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
