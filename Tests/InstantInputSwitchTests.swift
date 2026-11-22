// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Instant input switch and the first-letter guard it shares with the Super key.
enum InstantInputSwitchTests {
    static func run(_ suite: TestSuite) {
        triggers(suite)
        soloTap(suite)
        fnUsage(suite)
        guardSupport(suite)
        catalog(suite)
        strings(suite)
        rewrite(suite)
        deadKeys(suite)
        quickControlSpace(suite)
    }

    // MARK: - Triggers

    private static func triggers(_ suite: TestSuite) {
        suite.expect(InstantInputSwitchTrigger.sanitized(nil) == .controlSpace
                && InstantInputSwitchTrigger.sanitized("nonsense") == .controlSpace
                && InstantInputSwitchTrigger.sanitized("fn") == .fn,
               "an unknown or missing trigger falls back to Control-Space")
        suite.expect(InstantInputSwitchTrigger.rightCommand.isShadowed(bySuperKeySource: .rightCommand)
                && InstantInputSwitchTrigger.rightOption.isShadowed(bySuperKeySource: .rightOption)
                && !InstantInputSwitchTrigger.rightCommand.isShadowed(bySuperKeySource: .capsLock)
                && !InstantInputSwitchTrigger.fn.isShadowed(bySuperKeySource: .rightCommand)
                && !InstantInputSwitchTrigger.controlSpace.isShadowed(bySuperKeySource: .capsLock),
               "only a trigger on the Super key's own source key is shadowed by it")

        typealias Support = InstantInputSwitchSupport
        let fnDown = Support.modifierTriggerState(trigger: .fn, keyCode: 63, flags: .maskSecondaryFn)
        let fnUp = Support.modifierTriggerState(trigger: .fn, keyCode: 63, flags: [])
        let globeDown = Support.modifierTriggerState(trigger: .fn, keyCode: 179, flags: .maskSecondaryFn)
        suite.expect(fnDown == true && fnUp == false && globeDown == true,
               "Fn (63) and Globe (179) report down and up from the secondary-Fn flag")
        suite.expect(Support.modifierTriggerState(trigger: .fn, keyCode: 56, flags: .maskShift) == nil,
               "another modifier is not the Fn trigger")

        let rightCommand = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x10)
        let leftCommand = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x08)
        suite.expect(Support.modifierTriggerState(trigger: .rightCommand, keyCode: 54, flags: rightCommand) == true
                && Support.modifierTriggerState(trigger: .rightCommand, keyCode: 54, flags: leftCommand) == false
                && Support.modifierTriggerState(trigger: .rightCommand, keyCode: 55, flags: leftCommand) == nil,
               "right ⌘ is told from left ⌘ by its device bit and its key code")
        let rightOption = CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue | 0x40)
        suite.expect(Support.modifierTriggerState(trigger: .rightOption, keyCode: 61, flags: rightOption) == true
                && Support.modifierTriggerState(trigger: .rightOption, keyCode: 61, flags: []) == false
                && Support.modifierTriggerState(trigger: .rightOption, keyCode: 58, flags: .maskAlternate) == nil,
               "right ⌥ is told from left ⌥ by its device bit and its key code")
        suite.expect(Support.modifierTriggerState(trigger: .controlSpace, keyCode: 59, flags: .maskControl) == nil,
               "Control-Space is never a modifier trigger")

        suite.expect(Support.isControlSpace(keyCode: 49, flags: .maskControl)
                && Support.isControlSpace(keyCode: 49, flags: [.maskControl, .maskAlphaShift])
                && !Support.isControlSpace(keyCode: 49, flags: [.maskControl, .maskShift])
                && !Support.isControlSpace(keyCode: 49, flags: [.maskControl, .maskAlternate])
                && !Support.isControlSpace(keyCode: 49, flags: .maskCommand)
                && !Support.isControlSpace(keyCode: 49, flags: [])
                && !Support.isControlSpace(keyCode: 0, flags: .maskControl),
               "only Control with Space alone is Control-Space; Control-Option-Space stays the system's")
    }

    private static func soloTap(_ suite: TestSuite) {
        let millisecond: UInt64 = 1_000_000
        var tap = InstantInputSwitchSupport.SoloTap()
        tap.triggerDown(at: 1_000 * millisecond)
        suite.expect(tap.triggerUp(at: 1_120 * millisecond), "a quick press and release on its own is a tap")
        suite.expect(!tap.isDown, "the release ends the press")

        tap.triggerDown(at: 2_000 * millisecond)
        tap.otherInput()
        suite.expect(!tap.triggerUp(at: 2_100 * millisecond), "a chord is not a tap")

        tap.triggerDown(at: 3_000 * millisecond)
        suite.expect(!tap.triggerUp(at: 3_600 * millisecond), "a press held past half a second is a hold, not a tap")

        suite.expect(!tap.triggerUp(at: 4_000 * millisecond), "a release with no press before it does nothing")

        tap.otherInput()
        tap.triggerDown(at: 5_000 * millisecond)
        suite.expect(tap.triggerUp(at: 5_050 * millisecond), "input before the press does not spoil the tap")

        tap.triggerDown(at: 6_000 * millisecond)
        tap.triggerDown(at: 6_400 * millisecond)
        suite.expect(tap.triggerUp(at: 6_450 * millisecond),
               "a repeated down while held keeps the first press time")
    }

    private static func fnUsage(_ suite: TestSuite) {
        typealias Usage = InstantInputSwitchSupport.FnKeyUsage
        suite.expect(Usage(preferenceValue: 0) == .doNothing
                && Usage(preferenceValue: 1) == .changeInputSource
                && Usage(preferenceValue: 2) == .emojiAndSymbols
                && Usage(preferenceValue: 3) == .dictation
                && Usage(preferenceValue: nil) == .unknown
                && Usage(preferenceValue: 7) == .unknown,
               "AppleFnUsageType 0…3 read as Do Nothing, input source, emoji and dictation")
    }

    // MARK: - Guard

    private static func guardSupport(_ suite: TestSuite) {
        typealias Support = InputSourceGuardSupport
        suite.expect(InputSourceGuardStrategy.sanitized(nil) == .rewrite
                && InputSourceGuardStrategy.sanitized("replay") == .replay
                && InputSourceGuardStrategy.sanitized("nonsense") == .rewrite,
               "the guard falls back to rewriting")
        suite.expect(Support.sanitizedMilliseconds(100) == 100
                && Support.sanitizedMilliseconds(1500) == 1500
                && Support.sanitizedMilliseconds(50) == Support.defaultMilliseconds
                && Support.sanitizedMilliseconds(2000) == Support.defaultMilliseconds,
               "the guard window stays within 100…1500 ms")
        suite.expect(Support.isTyping(flags: [])
                && Support.isTyping(flags: [.maskShift, .maskAlternate, .maskAlphaShift])
                && !Support.isTyping(flags: .maskCommand)
                && !Support.isTyping(flags: .maskControl),
               "⌘ and ⌃ make a key a shortcut; ⇧, ⌥ and Caps Lock still type")
        suite.expect(Support.translationModifierState(flags: .maskShift) == 2
                && Support.translationModifierState(flags: .maskAlphaShift) == 4
                && Support.translationModifierState(flags: .maskAlternate) == 8
                && Support.translationModifierState(flags: .maskCommand) == 0,
               "UCKeyTranslate gets Shift, Caps Lock and Option in the shifted Carbon bits")
        // Control-Space goes back to the previous source, like macOS.
        suite.expect(Support.recording("uk", in: ["en", "uk", "de"]) == ["uk", "en", "de"]
                && Support.recording("fr", in: []) == ["fr"]
                && Support.recording("x", in: (0..<20).map(String.init)).count == Support.recentLimit,
               "a switch moves its source to the front of the recently used list, which stays bounded")
        let enabled = ["en", "uk", "de"]
        suite.expect(Support.previousSourceID(currentID: "uk", enabledIDs: enabled, recentIDs: ["uk", "en", "de"]) == "en"
                && Support.previousSourceID(currentID: "en", enabledIDs: enabled, recentIDs: ["en", "uk", "de"]) == "uk",
               "with three languages Control-Space flips between the two in use, not on through the list")
        suite.expect(Support.previousSourceID(currentID: "uk", enabledIDs: enabled, recentIDs: ["uk", "fr", "de"]) == "de",
               "a recent source that is no longer enabled is skipped")
        suite.expect(Support.previousSourceID(currentID: "en", enabledIDs: enabled, recentIDs: ["en"]) == "uk"
                && Support.previousSourceID(currentID: "en", enabledIDs: enabled, recentIDs: []) == "uk",
               "with no previous source yet it goes to the next one in the list")
        let history: [[String: Any]] = [
            ["InputSourceKind": "Keyboard Layout", "KeyboardLayout ID": -2354, "KeyboardLayout Name": "Ukrainian-PC"],
            ["InputSourceKind": "Input Mode", "Bundle ID": "com.apple.inputmethod.Kotoeri.RomajiTyping",
             "Input Mode": "com.apple.inputmethod.Japanese.Katakana"],
            ["InputSourceKind": "Keyboard Layout", "KeyboardLayout ID": 252, "KeyboardLayout Name": "ABC"],
            ["InputSourceKind": "Keyboard Layout", "KeyboardLayout ID": 0, "KeyboardLayout Name": "Removed"],
            ["InputSourceKind": "Keyboard Layout", "KeyboardLayout ID": 252, "KeyboardLayout Name": "ABC"],
            ["InputSourceKind": "Input Method", "Bundle ID": "org.example.inputmethod"],
            ["InputSourceKind": "Keyboard Layout", "KeyboardLayout ID": 9, "KeyboardLayout Name": "Custom"],
        ]
        let installed = ["com.apple.keylayout.ABC", "com.apple.keylayout.Ukrainian-PC",
                         "com.apple.inputmethod.Japanese.Katakana", "org.example.inputmethod",
                         "org.sil.ukelele.keyboardlayout.mine.Custom"]
        suite.expect(Support.historyIDs(history, enabledIDs: installed) == [
            "com.apple.keylayout.Ukrainian-PC", "com.apple.inputmethod.Japanese.Katakana",
            "com.apple.keylayout.ABC", "org.example.inputmethod", "org.sil.ukelele.keyboardlayout.mine.Custom",
        ], "macOS's own history maps to enabled source ids in order, once each, skipping removed sources")
        suite.expect(Support.historyIDs([], enabledIDs: installed).isEmpty,
               "no history leaves nothing to seed")
        suite.expect(Support.previousSourceID(currentID: "en", enabledIDs: ["en"], recentIDs: ["uk"]) == nil,
               "one enabled source leaves nothing to switch to")
        suite.expect(Support.typedText(Array("ф".utf16)) == "ф"
                && Support.typedText([]) == nil
                && Support.typedText([0x0D]) == nil
                && Support.typedText([0x7F]) == nil
                && Support.typedText([0xF700]) == nil,
               "only visible text is stamped: Return, Delete and arrows are left alone")
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.instantInputSwitch
        suite.expect(feature.isBeta && feature.group == .mouseKeyboard && !feature.installedByDefault,
               "Instant input switch is an opt-in BETA in Mouse and keyboard")
        suite.expect(feature.enabledKeys == [DefaultsKey.instantInputSwitchEnabled]
                && feature.permissions == [.accessibility]
                && feature.energyProfile == .keyboard,
               "it is one keyboard tap behind one switch, through Accessibility")
        let defaults = Defaults.registeredDefaults
        suite.expect(defaults[DefaultsKey.instantInputSwitchEnabled] as? Bool == false
                && defaults[DefaultsKey.instantInputSwitchTrigger] as? String == "controlSpace"
                && defaults[DefaultsKey.inputSourceGuardEnabled] as? Bool == true
                && defaults[DefaultsKey.inputSourceGuardStrategy] as? String == "rewrite"
                && defaults[DefaultsKey.inputSourceGuardMilliseconds] as? Int == 300,
               "it ships off, on Control-Space, with the guard rewriting for 300 ms")
        suite.expect(defaults[DefaultsKey.panelControlInstantInputSwitch] as? Bool == true
                && SettingsBackupSupport.exportKeys().contains(DefaultsKey.panelControlInstantInputSwitch),
               "its menu panel row shows by default and travels with a settings backup")
        suite.expect(OwnKeyEvent.isPosted(sourceProcessID: 0, userData: OwnKeyEvent.instantInputSwitchMarker,
                                          ownProcessID: 1)
                && OwnKeyEvent.isPosted(sourceProcessID: 0, userData: OwnKeyEvent.superKeyInputGuardMarker,
                                        ownProcessID: 1),
               "replayed copies are recognised as the app's own keys by every other filter")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = FeatureStrings.instantInputSwitch(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(!values.isEmpty && values.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                   "every Instant input switch string is written for \(language.rawValue)")
            suite.expect(text.millisecondsFormat.contains("%d")
                    && String(format: text.millisecondsFormat, 300).contains("300"),
                   "the window format shows its milliseconds in \(language.rawValue)")
            let triggers = Set(InstantInputSwitchTrigger.allCases.map(text.triggerLabel))
            let strategies = Set(InputSourceGuardStrategy.allCases.map(text.strategyLabel))
            suite.expect(triggers.count == InstantInputSwitchTrigger.allCases.count
                    && strategies.count == InputSourceGuardStrategy.allCases.count,
                   "every trigger and method has its own label in \(language.rawValue)")
            if language != .enUS {
                suite.expect(text.pageTitle != InstantInputSwitchStrings.enUS.pageTitle
                        && text.guardCaption != InstantInputSwitchStrings.enUS.guardCaption,
                       "\(language.rawValue) is translated, not the English text")
            }
        }
    }

    // MARK: - Rewrite against a real layout

    private static func rewrite(_ suite: TestSuite) {
        guard let ukrainian = layoutData("com.apple.keylayout.Ukrainian-PC") else {
            suite.expect(true, "no Ukrainian layout installed: the rewrite check is skipped")
            return
        }
        let millisecond: UInt64 = 1_000_000
        let switchedAt: UInt64 = 10_000 * millisecond
        let selection = InputSourceSwitcher.Selection(id: "com.apple.keylayout.Ukrainian-PC", name: "Ukrainian",
                                                      layout: ukrainian, keyboardType: UInt32(LMGetKbdType()))
        let guarded = InputSourceGuard(marker: OwnKeyEvent.instantInputSwitchMarker, holdsClicks: true)
        let settings = InputSourceGuard.Settings(enabled: true, strategy: .rewrite, milliseconds: 300)
        suite.expect(guarded.arm(for: selection, at: switchedAt, settings: settings) == .rewrite,
               "a switch to a keyboard layout arms the rewrite")

        func outcome(_ keyCode: Int, flags: CGEventFlags = [], after milliseconds: UInt64,
                     rewriteAllowed: Bool = true) -> (passed: Bool, text: String) {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
            else { return (false, "") }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUnixProcessID, value: 0)
            let sentinel = Array("#".utf16)
            event.keyboardSetUnicodeString(stringLength: sentinel.count, unicodeString: sentinel)
            let passed = guarded.process(type: .keyDown, event: event,
                                         timestamp: switchedAt + milliseconds * millisecond,
                                         rewriteAllowed: rewriteAllowed)
            var length = 0
            var units = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length,
                                           unicodeString: &units)
            return (passed, String(utf16CodeUnits: units, count: length))
        }

        let first = outcome(kVK_ANSI_A, after: 10)
        suite.expect(first.passed && first.text == "ф", "the first letter after the switch types the new layout")
        suite.expect(outcome(kVK_ANSI_A, flags: .maskShift, after: 20).text == "Ф",
               "Shift is translated with the new layout too")
        suite.expect(outcome(kVK_ANSI_C, flags: .maskCommand, after: 30).text == "#",
               "⌘C is a shortcut and keeps its own event")
        suite.expect(outcome(kVK_Return, after: 40).text == "#", "Return is not stamped")
        suite.expect(outcome(kVK_ANSI_A, after: 50, rewriteAllowed: false).text == "#",
               "the owner's veto (a Super key chord) is honoured")
        suite.expect(outcome(kVK_ANSI_A, after: 400).text == "#", "keys after the window are left to the app")
        suite.expect(outcome(kVK_ANSI_A, after: 410).text == "#", "the window does not reopen by itself")

        let off = InputSourceGuard.Settings(enabled: false, strategy: .rewrite, milliseconds: 300)
        suite.expect(guarded.arm(for: selection, at: switchedAt, settings: off) == nil
                && outcome(kVK_ANSI_A, after: 10).text == "#",
               "with the guard off a switch arms nothing")

        // Replay holds keys. The window is reset before its flush timer can
        // run, so nothing is ever posted from a test.
        let replay = InputSourceGuard.Settings(enabled: true, strategy: .replay, milliseconds: 300)
        suite.expect(guarded.arm(for: selection, at: switchedAt, settings: replay) == .replay,
               "the replay method arms a hold")
        suite.expect(!outcome(kVK_ANSI_A, after: 10).passed, "a key inside a replay window is held")
        guarded.reset()
        suite.expect(outcome(kVK_ANSI_A, after: 20).passed, "a reset lets keys through again")
    }

    /// A dead key waits for the next key inside an app that may still be on
    /// the old layout, so the guard steps aside instead of composing.
    private static func deadKeys(_ suite: TestSuite) {
        guard let international = layoutData("com.apple.keylayout.USInternational-PC") else {
            suite.expect(true, "no U.S. International layout installed: the dead key check is skipped")
            return
        }
        let millisecond: UInt64 = 1_000_000
        let switchedAt: UInt64 = 20_000 * millisecond
        let guarded = InputSourceGuard(marker: OwnKeyEvent.instantInputSwitchMarker, holdsClicks: true)
        let selection = InputSourceSwitcher.Selection(id: "com.apple.keylayout.USInternational-PC",
                                                      name: "U.S. International", layout: international,
                                                      keyboardType: UInt32(LMGetKbdType()))
        _ = guarded.arm(for: selection, at: switchedAt,
                        settings: InputSourceGuard.Settings(enabled: true, strategy: .rewrite, milliseconds: 300))
        func stamped(_ keyCode: Int, after milliseconds: UInt64) -> String {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)
            else { return "" }
            event.flags = []
            event.setIntegerValueField(.eventSourceUnixProcessID, value: 0)
            let sentinel = Array("#".utf16)
            event.keyboardSetUnicodeString(stringLength: sentinel.count, unicodeString: sentinel)
            _ = guarded.process(type: .keyDown, event: event, timestamp: switchedAt + milliseconds * millisecond)
            var length = 0
            var units = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length,
                                           unicodeString: &units)
            return String(utf16CodeUnits: units, count: length)
        }
        suite.expect(stamped(kVK_ANSI_A, after: 10) == "a", "a plain key is stamped before any dead key")
        suite.expect(stamped(kVK_ANSI_Quote, after: 20) == "#",
               "a dead key (´ on U.S. International) goes on untouched")
        suite.expect(stamped(kVK_ANSI_E, after: 30) == "#",
               "the key after a dead key is left to the app to compose, not stamped as a plain e")
    }

    /// Two quick Control-Space presses, the second before macOS's notice of
    /// the first arrives, in the order the service applies them.
    private static func quickControlSpace(_ suite: TestSuite) {
        let enabled = ["en", "uk", "de"]
        var recents = InputSourceRecents()
        var current = "en"
        // The last time the user toggled, it was between English and German.
        recents.seed(["en", "de"])
        recents.noticed(current)
        func press() -> String? {
            guard let target = recents.previous(currentID: current, enabledIDs: enabled) else { return nil }
            recents.switched(from: current, to: target)
            current = target
            return target
        }
        suite.expect(press() == "de", "the first press after a start goes where macOS's own history says")
        suite.expect(press() == "en", "a second quick press goes back, before any notice arrives")
        recents.noticed(current)
        recents.noticed(current)
        suite.expect(press() == "de", "late notices for the earlier presses change nothing")
        current = "uk"
        recents.noticed(current)
        suite.expect(press() == "de", "after a switch from the Input menu, Control-Space goes back to the source used before it")

        // TIS keeps its old report until the main run loop delivers the
        // notice. Presses queued behind a busy main thread all see it.
        typealias Support = InputSourceGuardSupport
        let threeSources = ["a", "b", "c"]
        var last: Support.LastSwitch?
        var clock = 100.0
        func queuedPress(reported: String) -> String? {
            let current = Support.effectiveCurrentID(reported: reported, lastSwitch: last, now: clock)
            guard let next = SuperKeySupport.nextInputSourceID(currentID: current, enabledIDs: threeSources)
            else { return nil }
            last = Support.LastSwitch(reported: reported, selected: next, at: clock)
            clock += 0.05
            return next
        }
        suite.expect([queuedPress(reported: "a"), queuedPress(reported: "a"), queuedPress(reported: "a")]
                        == ["b", "c", "a"],
               "three presses queued before any notice walk a → b → c → a, not back to b")
        last?.confirmed = true
        suite.expect(Support.effectiveCurrentID(reported: "b", lastSwitch: last, now: clock) == "b",
               "once the notice has arrived the report is believed, even one naming an older source")
        last = Support.LastSwitch(reported: "a", selected: "b", at: 100)
        suite.expect(Support.effectiveCurrentID(reported: "a", lastSwitch: last, now: 101.5) == "a",
               "a second on, an unchanged report is believed: the switch is not still in flight")
        suite.expect(Support.effectiveCurrentID(reported: "c", lastSwitch: last, now: 100.2) == "c"
                && Support.effectiveCurrentID(reported: "a", lastSwitch: nil, now: 100.2) == "a",
               "a different report, or no switch of this app's to compare with, is taken as it is")

        // Control-Space twice behind a busy main thread: the second press
        // still sees the old report and must go back.
        var queuedRecents = InputSourceRecents()
        queuedRecents.seed(["en", "uk"])
        var lastToggle: Support.LastSwitch?
        func queuedToggle(reported: String, at time: Double) -> String? {
            let current = Support.effectiveCurrentID(reported: reported, lastSwitch: lastToggle, now: time)
            guard let target = queuedRecents.previous(currentID: current, enabledIDs: enabled) else { return nil }
            queuedRecents.switched(from: current, to: target)
            lastToggle = Support.LastSwitch(reported: reported, selected: target, at: time)
            return target
        }
        suite.expect(queuedToggle(reported: "en", at: 200) == "uk"
                && queuedToggle(reported: "en", at: 200.08) == "en",
               "a double Control-Space before any notice goes there and back")

        var fresh = InputSourceRecents()
        fresh.seed([])
        fresh.noticed("en")
        suite.expect(fresh.previous(currentID: "en", enabledIDs: enabled) == "uk",
               "with no history at all the first press goes to the next source in the list")
    }

    private static func layoutData(_ id: String) -> Data? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as NSArray?,
              let source = list.firstObject.map({ $0 as! TISInputSource }),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    }
}
