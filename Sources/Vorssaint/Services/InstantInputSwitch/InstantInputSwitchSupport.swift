// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// The key that switches the input source when Instant input switch is on.
/// Raw values are persisted, so cases can be added but never renamed.
enum InstantInputSwitchTrigger: String, CaseIterable, Identifiable {
    /// Control-Space, taken over from macOS for as long as the feature runs.
    case controlSpace
    /// The Fn/Globe key tapped on its own.
    case fn
    case rightCommand
    case rightOption

    var id: String { rawValue }

    static func sanitized(_ raw: String?) -> InstantInputSwitchTrigger {
        raw.flatMap(InstantInputSwitchTrigger.init(rawValue:)) ?? .controlSpace
    }

    /// The Super key remaps its own source key, so a trigger on that same key
    /// never reaches this feature's tap.
    func isShadowed(bySuperKeySource source: SuperKeySource) -> Bool {
        switch (self, source) {
        case (.rightCommand, .rightCommand), (.rightOption, .rightOption): return true
        default: return false
        }
    }
}

/// The pure half of Instant input switch: which events are the trigger and
/// when a tap counts as a tap. The first-letter guard lives in
/// `InputSourceGuardSupport`, shared with the Super key.
enum InstantInputSwitchSupport {
    /// A press held longer than this is a hold, not a tap, and switches nothing.
    static let soloTapMaxNanoseconds: UInt64 = 500_000_000

    static let spaceKeyCode = Int64(kVK_Space)
    /// The Fn key reports 63; some Globe keyboards report 179 instead.
    static let fnKeyCodes: Set<Int64> = [Int64(kVK_Function), 179]
    static let rightCommandKeyCode = Int64(kVK_RightCommand)
    static let rightOptionKeyCode = Int64(kVK_RightOption)
    // Device-dependent modifier bits from IOLLEvent.h: they tell the right
    // key from the left one, which the generic flags cannot.
    static let deviceRightCommandMask: UInt64 = 0x10
    static let deviceRightOptionMask: UInt64 = 0x40

    static let controlSpace = GlobalShortcut(keyCode: spaceKeyCode, modifiers: .control)
    /// "Select the previous input source" and "Select next source in Input
    /// menu" in the WindowServer's symbolic hotkey table.
    static let inputSourceHotKeyIDs: Set<Int32> = [60, 61]

    /// What macOS does on the 🌐 key ("Press 🌐 key to" in Keyboard
    /// settings), read from `AppleFnUsageType` in com.apple.HIToolbox.
    enum FnKeyUsage: Equatable {
        case doNothing
        case changeInputSource
        case emojiAndSymbols
        /// Dictation starts on a double press only.
        case dictation
        /// Never written: macOS uses its own default, which differs between
        /// versions, so it cannot be told apart from a choice.
        case unknown

        init(preferenceValue: Int?) {
            switch preferenceValue {
            case 0?: self = .doNothing
            case 1?: self = .changeInputSource
            case 2?: self = .emojiAndSymbols
            case 3?: self = .dictation
            default: self = .unknown
            }
        }
    }

    static func isControlSpace(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == spaceKeyCode && GlobalShortcutModifiers(cgFlags: flags) == .control
    }

    /// For a modifier trigger, whether this flags-changed event says the
    /// trigger key is now down (true) or up (false). Nil when the event is
    /// about some other key, or the trigger is not a modifier.
    static func modifierTriggerState(trigger: InstantInputSwitchTrigger,
                                     keyCode: Int64,
                                     flags: CGEventFlags) -> Bool? {
        switch trigger {
        case .controlSpace:
            return nil
        case .fn:
            guard fnKeyCodes.contains(keyCode) else { return nil }
            return flags.contains(.maskSecondaryFn)
        case .rightCommand:
            guard keyCode == rightCommandKeyCode else { return nil }
            return flags.rawValue & deviceRightCommandMask != 0
        case .rightOption:
            guard keyCode == rightOptionKeyCode else { return nil }
            return flags.rawValue & deviceRightOptionMask != 0
        }
    }

    /// Whether the Super key's own key (F18 once its mapping is in) is down,
    /// as this tap sees it. This tap runs ahead of the Super key's, and while
    /// the first-letter guard holds that press the Super key has not heard of
    /// it yet: a letter pressed meanwhile belongs to a chord, and giving it
    /// the new layout's text could turn ⌘K into ⌘Л for an app that matches
    /// shortcuts by character.
    struct SuperKeyPress: Equatable {
        private(set) var isDown = false

        mutating func note(keyCode: Int64, down: Bool) {
            guard keyCode == SuperKeySupport.triggerKeyCode else { return }
            isDown = down
        }

        /// A press whose release this tap may never see (the tap was off, or
        /// the Super key let go of its key meanwhile) is forgotten.
        mutating func reset() { isDown = false }
    }

    /// A modifier pressed and released with nothing else in between, quickly.
    /// Anything else pressed meanwhile (a key, another modifier, a click)
    /// makes it a chord, which must keep doing whatever it already does.
    struct SoloTap: Equatable {
        private(set) var isDown = false
        private var isAlone = false
        private var downAt: UInt64 = 0

        mutating func triggerDown(at timestamp: UInt64) {
            guard !isDown else { return }
            isDown = true
            isAlone = true
            downAt = timestamp
        }

        mutating func otherInput() {
            if isDown { isAlone = false }
        }

        /// True when this release ends a tap that should switch.
        mutating func triggerUp(at timestamp: UInt64) -> Bool {
            defer { reset() }
            return isDown && isAlone && timestamp >= downAt
                && timestamp - downAt <= InstantInputSwitchSupport.soloTapMaxNanoseconds
        }

        mutating func reset() {
            isDown = false
            isAlone = false
            downAt = 0
        }
    }
}
