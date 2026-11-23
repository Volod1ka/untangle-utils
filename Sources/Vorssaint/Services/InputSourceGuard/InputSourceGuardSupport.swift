// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// How the keys typed right after an input source switch are kept in the new
/// layout. Raw values are persisted, so cases can be added but never renamed.
enum InputSourceGuardStrategy: String, CaseIterable, Identifiable {
    /// Stamp each key with the character the new layout types. Instant, but
    /// only possible for plain keyboard layouts.
    case rewrite
    /// Hold the keys back and send them again once the window is over.
    case replay

    var id: String { rawValue }

    static func sanitized(_ raw: String?) -> InputSourceGuardStrategy {
        raw.flatMap(InputSourceGuardStrategy.init(rawValue:)) ?? .rewrite
    }
}

/// The pure half of the first-letter guard shared by every path that switches
/// the input source from a keyboard tap (Instant input switch, the Super key).
///
/// The problem it exists for: macOS selects a new input source at once, but
/// each app picks the change up on its own, later. Keys typed in between come
/// out in the old layout, which on macOS 26 can be the first letter or two of
/// every word typed right after a switch.
enum InputSourceGuardSupport {
    static let defaultMilliseconds = 300
    static let millisecondsRange = 100...1500
    static let millisecondsStep = 50

    static func sanitizedMilliseconds(_ value: Int) -> Int {
        millisecondsRange.contains(value) ? value : defaultMilliseconds
    }

    // MARK: - Choosing the source

    /// How many recently used sources are remembered for "previous".
    static let recentLimit = 8

    /// The recently used sources with `id` now in front, the way macOS keeps
    /// them for "Select the previous input source".
    static func recording(_ id: String, in recent: [String]) -> [String] {
        Array(([id] + recent.filter { $0 != id }).prefix(recentLimit))
    }

    /// Control-Space in macOS goes back to the source used before this one,
    /// not on through the list: with three languages it flips between the
    /// two in use. Falls back to the next in the list when nothing enabled
    /// was used before.
    static func previousSourceID(currentID: String?, enabledIDs: [String], recentIDs: [String]) -> String? {
        guard enabledIDs.count > 1 else { return nil }
        return recentIDs.first { $0 != currentID && enabledIDs.contains($0) }
            ?? SuperKeySupport.nextInputSourceID(currentID: currentID, enabledIDs: enabledIDs)
    }

    /// The sources in macOS's own history (`AppleInputSourceHistory` in
    /// com.apple.HIToolbox, most recent first) as enabled source ids, so
    /// "previous" is right from the first press and after a pause. A layout
    /// is stored by its layout name, an input method mode by its id, a method
    /// without modes by its bundle id. A layout name need not match the id
    /// (U.S. is `com.apple.keylayout.US`), so
    /// `layoutNames`, each enabled layout's own name → its id as TIS reports
    /// them, is asked first, then the id itself.
    static func historyIDs(_ entries: [[String: Any]], enabledIDs: [String],
                           layoutNames: [String: String] = [:]) -> [String] {
        var ids: [String] = []
        for entry in entries {
            let id: String?
            if let mode = entry["Input Mode"] as? String {
                id = enabledIDs.contains(mode) ? mode : nil
            } else if let name = entry["KeyboardLayout Name"] as? String, !name.isEmpty {
                id = layoutNames[name].flatMap { enabledIDs.contains($0) ? $0 : nil }
                    ?? enabledIDs.first { $0 == "com.apple.keylayout.\(name)" }
                    ?? enabledIDs.first { $0.hasSuffix(".\(name)") }
            } else if let bundle = entry["Bundle ID"] as? String {
                id = enabledIDs.contains(bundle) ? bundle : nil
            } else {
                id = nil
            }
            if let id, !ids.contains(id) { ids.append(id) }
        }
        return Array(ids.prefix(recentLimit))
    }

    /// How long after this app's own switch a report of the source it left
    /// is taken as stale.
    static let staleReportSeconds: TimeInterval = 1

    /// This process's last switch, as the stale-report check needs it.
    struct LastSwitch: Equatable {
        /// What TIS reported as current when the switch was made.
        var reported: String?
        /// What the switch selected.
        var selected: String
        var at: TimeInterval
        /// Set once macOS's "selected source changed" notice has reached this
        /// process: from then on TIS reports what is really current.
        var confirmed = false
    }

    /// The source to count from. TIS learns of a selection through a notice
    /// the main run loop delivers, so until that loop turns it keeps
    /// reporting what it reported before (Tools/CheckInputSourceSwitch.swift
    /// shows both cases). Presses queued behind a busy main thread would each
    /// count from that old report: the second would go nowhere, a third back
    /// to the start. So while no notice has arrived since this app's last
    /// switch, and for at most a second, the same report means the source
    /// that switch selected. Any notice, this app's or another's, ends that.
    static func effectiveCurrentID(reported: String?, lastSwitch: LastSwitch?, now: TimeInterval) -> String? {
        guard let lastSwitch, !lastSwitch.confirmed, reported == lastSwitch.reported,
              now >= lastSwitch.at, now - lastSwitch.at < staleReportSeconds else { return reported }
        return lastSwitch.selected
    }

    // MARK: - The guard

    /// More events than this in one replay window go out at once.
    static let replayLimit = 128

    /// Command and Control make a key a shortcut. Its menu dispatch breaks
    /// when the event carries a forced character string, so those keys are
    /// never rewritten.
    static func isTyping(flags: CGEventFlags) -> Bool {
        !flags.contains(.maskCommand) && !flags.contains(.maskControl)
    }

    /// The modifier state UCKeyTranslate wants: the Carbon modifier bits
    /// shifted down out of the event record's high byte.
    static func translationModifierState(flags: CGEventFlags) -> UInt32 {
        (flags.contains(.maskShift) ? UInt32((shiftKey >> 8) & 0xFF) : 0)
            | (flags.contains(.maskAlternate) ? UInt32((optionKey >> 8) & 0xFF) : 0)
            | (flags.contains(.maskAlphaShift) ? UInt32((alphaLock >> 8) & 0xFF) : 0)
    }

    /// The text a translated key may carry, or nil when the key types no
    /// visible character: Return, Tab, Delete, Escape, arrows and function
    /// keys translate to control characters or private-use codes, and are
    /// left exactly as they are.
    static func typedText(_ units: [UniChar]) -> String? {
        guard !units.isEmpty else { return nil }
        let text = String(utf16CodeUnits: units, count: units.count)
        let typesVisibleText = text.unicodeScalars.allSatisfy {
            $0.value >= 0x20 && $0.value != 0x7F && !(0xF700...0xF8FF).contains($0.value)
        }
        return typesVisibleText ? text : nil
    }
}

/// The recently used sources behind "previous", most recent first, and the
/// order of updates a tap follows so two quick presses work.
struct InputSourceRecents: Equatable {
    private(set) var ids: [String] = []

    /// Replaces the history with macOS's own, at start and after a pause.
    mutating func seed(_ history: [String]) {
        ids = Array(history.prefix(InputSourceGuardSupport.recentLimit))
    }

    /// A source macOS reports as current, whoever selected it.
    mutating func noticed(_ id: String) {
        ids = InputSourceGuardSupport.recording(id, in: ids)
    }

    /// A switch this app made, recorded at once: a second press before the
    /// system's notice arrives must already go back from the new source.
    mutating func switched(from previous: String?, to id: String) {
        if let previous { noticed(previous) }
        noticed(id)
    }

    func previous(currentID: String?, enabledIDs: [String]) -> String? {
        InputSourceGuardSupport.previousSourceID(currentID: currentID, enabledIDs: enabledIDs, recentIDs: ids)
    }
}
