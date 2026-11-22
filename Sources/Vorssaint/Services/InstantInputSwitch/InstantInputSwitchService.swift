// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import CoreGraphics
import Foundation
import os

/// Switches the keyboard input source from its own trigger, without the
/// system's switcher, and keeps the keys typed right after the switch in the
/// new layout through the shared `InputSourceGuard` (BETA).
///
/// Trigger and confirmation times are logged under the "InstantInputSwitch"
/// category, never what was typed.
final class InstantInputSwitchService: ObservableObject {
    static let shared = InstantInputSwitchService()

    @Published private(set) var isRunning = false
    /// What macOS itself does on the 🌐 key, so the page can say when it
    /// would switch the language too. Main thread only.
    @Published private(set) var fnUsage = InstantInputSwitchSupport.FnKeyUsage.unknown

    static let takeOverSource = "instantInputSwitch"
    fileprivate static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "InstantInputSwitch")

    private struct Config: Equatable {
        var enabled = false
        var trigger = InstantInputSwitchTrigger.controlSpace
    }

    // Lifecycle. The tap runs on its own user-interactive thread so a busy
    // main thread never delays typing.
    private let lifecycleLock = NSLock()
    private var tap: CFMachPort?
    private var tapRunLoop: CFRunLoop?
    private var tapThread: Thread?
    private var shouldStopTapThread = false
    private var pendingStartAfterStop = false
    private var lifecycleGeneration: UInt = 0

    // Event state, guarded by stateLock.
    private let stateLock = NSLock()
    private var config = Config()
    private var soloTap = InstantInputSwitchSupport.SoloTap()
    private var swallowingSpaceUp = false
    /// When the last switch began, to log how long macOS took to confirm it.
    private var switchedAtNanoseconds: UInt64 = 0

    /// Reached from the tap thread and from stop() on main, so it is built
    /// eagerly: a lazy property is not safe to initialize from two threads.
    /// This tap watches both halves of a click, so the guard may hold clicks.
    private let inputGuard = InputSourceGuard(marker: OwnKeyEvent.instantInputSwitchMarker,
                                              holdsClicks: true) { activity in
        if case .replayed(let keys) = activity {
            InstantInputSwitchService.log.notice("replayed \(keys, privacy: .public) held keys")
        }
    }

    // Main thread only.
    private var inputSourceObserver: NSObjectProtocol?
    private var secureInputWatch: SecureInputWatch?
    private var wantsTakeOver = false

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    // MARK: - Preferences

    func syncWithPreferences() {
        let defaults = UserDefaults.standard
        let next = Config(
            enabled: AppFeature.instantInputSwitch.isAvailable
                && defaults.bool(forKey: DefaultsKey.instantInputSwitchEnabled),
            trigger: InstantInputSwitchTrigger.sanitized(
                defaults.string(forKey: DefaultsKey.instantInputSwitchTrigger))
        )
        // swallowingSpaceUp is left alone: a Control-Space whose key-down was
        // swallowed still owns its key-up, whatever setting changed meanwhile.
        stateLock.withLock {
            config = next
            soloTap.reset()
        }

        let shouldRun = SessionActivitySupport.tapShouldRun(featureWanted: next.enabled,
                                                            accessibilityGranted: AXIsProcessTrusted(),
                                                            sessionIsActive: SessionActivity.shared.isActive)
        if shouldRun {
            start()
        } else {
            stop()
        }
        runOnMain { self.applyWatchers(running: shouldRun) }
    }

    func suspend() {
        stop()
        runOnMain { self.applyWatchers(running: false) }
    }

    // MARK: - Watchers and the Control-Space take-over

    private func applyWatchers(running: Bool) {
        // Control-Space's "previous" reads the shared history.
        InputSourceRecentsTracker.shared.hold(running, for: Self.takeOverSource)
        if running {
            if inputSourceObserver == nil {
                inputSourceObserver = DistributedNotificationCenter.default().addObserver(
                    forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
                    object: nil, queue: .main
                ) { [weak self] _ in self?.inputSourceDidChange() }
            }
            refreshFnUsage()
        } else if let observer = inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            inputSourceObserver = nil
        }
        refreshTakeOver()
    }

    /// Rereads "Press 🌐 key to". The settings page calls it whenever the app
    /// comes back to the front, which is when a change made in System
    /// Settings can have happened.
    func refreshFnUsage() {
        let domain = "com.apple.HIToolbox" as CFString
        // This process caches other domains; ask for what is on disk now.
        CFPreferencesAppSynchronize(domain)
        let value = CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, domain) as? Int
        let usage = InstantInputSwitchSupport.FnKeyUsage(preferenceValue: value)
        if usage != fnUsage {
            Self.log.notice("AppleFnUsageType=\(value.map(String.init) ?? "unset", privacy: .public)")
            fnUsage = usage
        }
    }

    /// Control-Space is taken from macOS only while the tap is actually live
    /// to answer it, never merely because the setting is on: a refused tap
    /// must leave the system's own switching in place.
    private func refreshTakeOver() {
        let trigger = stateLock.withLock { config.trigger }
        wantsTakeOver = isRunning && trigger == .controlSpace
        if wantsTakeOver {
            if secureInputWatch == nil {
                secureInputWatch = SecureInputWatch { [weak self] _ in self?.applyTakeOver() }
            }
            secureInputWatch?.start()
        } else {
            secureInputWatch?.stop()
        }
        applyTakeOver()
    }

    /// Under Secure Event Input (a password field) the tap is deaf, so the key
    /// is handed back to macOS for that stretch instead of doing nothing.
    private func applyTakeOver() {
        guard wantsTakeOver, !IsSecureEventInputEnabled() else {
            SystemShortcutTakeover.setWanted([], for: Self.takeOverSource)
            return
        }
        let entries = SymbolicHotKeys.entries(for: InstantInputSwitchSupport.inputSourceHotKeyIDs) ?? []
        SystemShortcutTakeover.setWanted(
            SystemShortcutTakeoverSupport.ids(matching: InstantInputSwitchSupport.controlSpace, in: entries),
            for: Self.takeOverSource)
    }

    private func inputSourceDidChange() {
        let now = Self.nowNanoseconds()
        let elapsed = stateLock.withLock { () -> Int? in
            let startedAt = switchedAtNanoseconds
            guard startedAt > 0, now >= startedAt, now - startedAt < 3_000_000_000 else { return nil }
            // One confirmation per switch.
            switchedAtNanoseconds = 0
            return Int((now - startedAt) / 1_000_000)
        }
        guard let elapsed else {
            Self.log.notice("input source changed (not by this feature, or a repeated notice)")
            return
        }
        Self.log.notice("switch confirmed by the system after \(elapsed, privacy: .public) ms")
    }

    // MARK: - Tap lifecycle

    private func start() {
        let thread = lifecycleLock.withLock { () -> Thread? in
            if tapThread != nil {
                if shouldStopTapThread { pendingStartAfterStop = true }
                return nil
            }
            shouldStopTapThread = false
            pendingStartAfterStop = false
            lifecycleGeneration &+= 1
            let generation = lifecycleGeneration
            let thread = Thread { [weak self] in self?.runEventTap(generation: generation) }
            thread.name = "Vorssaint Instant Input Switch"
            thread.qualityOfService = .userInteractive
            tapThread = thread
            return thread
        }
        thread?.start()
    }

    private func stop() {
        stateLock.withLock { soloTap.reset() }
        let snapshot = lifecycleLock.withLock {
            () -> (runLoop: CFRunLoop?, tap: CFMachPort?, threadExists: Bool, generation: UInt) in
            shouldStopTapThread = true
            pendingStartAfterStop = false
            lifecycleGeneration &+= 1
            return (tapRunLoop, tap, tapThread != nil, lifecycleGeneration)
        }
        if let tap = snapshot.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoop = snapshot.runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { CFRunLoopStop(runLoop) }
            CFRunLoopWakeUp(runLoop)
        } else if !snapshot.threadExists {
            lifecycleLock.withLock {
                shouldStopTapThread = false
                tapThread = nil
            }
        }
        publishRunning(false, generation: snapshot.generation)
    }

    private func runEventTap(generation: UInt) {
        autoreleasepool {
            let runLoop = CFRunLoopGetCurrent()
            lifecycleLock.withLock { tapRunLoop = runLoop }
            guard !lifecycleLock.withLock({ shouldStopTapThread }) else {
                if clearEventTapThread() { start() } else { publishRunning(false, generation: generation) }
                return
            }

            var mask = CGEventMask(1) << CGEventType.keyDown.rawValue
            for type in [CGEventType.keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown,
                         .otherMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp, .scrollWheel] {
                mask |= CGEventMask(1) << type.rawValue
            }
            guard let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, userInfo in
                    guard let userInfo else { return Unmanaged.passUnretained(event) }
                    let service = Unmanaged<InstantInputSwitchService>.fromOpaque(userInfo).takeUnretainedValue()
                    return service.handle(type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                Self.log.error("keyboard tap refused")
                _ = clearEventTapThread()
                publishRunning(false, generation: generation)
                return
            }

            stateLock.withLock {
                soloTap.reset()
                swallowingSpaceUp = false
            }
            inputGuard.reset()

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            lifecycleLock.withLock { self.tap = tap }
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)

            if !lifecycleLock.withLock({ shouldStopTapThread }) {
                publishRunning(true, generation: generation)
                CFRunLoopRun()
            }

            CGEvent.tapEnable(tap: tap, enable: false)
            // Held keys go out rather than being lost with the tap. Done here,
            // on the tap's thread once it hears nothing more, so no key can
            // slip into the queue after it was emptied.
            inputGuard.flush(endingWindow: true)
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFMachPortInvalidate(tap)
            if clearEventTapThread() { start() } else { publishRunning(false, generation: generation) }
        }
    }

    private func clearEventTapThread() -> Bool {
        lifecycleLock.withLock {
            let shouldRestart = pendingStartAfterStop
            tap = nil
            tapRunLoop = nil
            tapThread = nil
            shouldStopTapThread = false
            pendingStartAfterStop = false
            return shouldRestart
        }
    }

    private func publishRunning(_ running: Bool, generation: UInt) {
        runOnMain {
            guard self.lifecycleLock.withLock({ generation == self.lifecycleGeneration }) else { return }
            self.isRunning = running
            self.refreshTakeOver()
        }
    }

    // MARK: - Events

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            let currentTap = lifecycleLock.withLock { shouldStopTapThread ? nil : tap }
            if SessionActivity.shared.isActive, AXIsProcessTrusted(), let currentTap {
                CGEvent.tapEnable(tap: currentTap, enable: true)
            } else if currentTap != nil {
                DispatchQueue.main.async { [weak self] in self?.syncWithPreferences() }
            }
            stateLock.withLock { soloTap.reset() }
            return Unmanaged.passUnretained(event)
        }
        // This guard's own replayed copies, then snippets and other keys this
        // app types itself.
        if inputGuard.absorbReplay(event) || OwnKeyEvent.isPosted(event) {
            return Unmanaged.passUnretained(event)
        }

        let timestamp = EventTimestamp.nanoseconds(of: event)
        switch type {
        case .scrollWheel:
            // ⌘-scroll to zoom is a chord, not a tap of ⌘.
            stateLock.withLock { soloTap.otherInput() }
            return Unmanaged.passUnretained(event)

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            stateLock.withLock { soloTap.otherInput() }
            return guarded(type: type, event: event, timestamp: timestamp)

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return guarded(type: type, event: event, timestamp: timestamp)

        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let trigger = stateLock.withLock { config.trigger }
            if InstantInputSwitchSupport.fnKeyCodes.contains(keyCode) {
                // The prototype's main open question: does Fn reach the tap at
                // all, and with which key code.
                let state = event.flags.contains(.maskSecondaryFn) ? "down" : "up"
                Self.log.notice("fn \(state, privacy: .public) keyCode=\(keyCode, privacy: .public)")
            }
            guard let isDown = InstantInputSwitchSupport.modifierTriggerState(
                trigger: trigger, keyCode: keyCode, flags: event.flags) else {
                stateLock.withLock { soloTap.otherInput() }
                return Unmanaged.passUnretained(event)
            }
            if isDown {
                stateLock.withLock { soloTap.triggerDown(at: timestamp) }
            } else if stateLock.withLock({ soloTap.triggerUp(at: timestamp) }) {
                switchInputSource(trigger: trigger, at: timestamp)
            }
            // The modifier itself always carries on: it still has to work as one.
            return Unmanaged.passUnretained(event)

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let trigger = stateLock.withLock { () -> InstantInputSwitchTrigger in
                soloTap.otherInput()
                return config.trigger
            }
            if trigger == .controlSpace,
               InstantInputSwitchSupport.isControlSpace(keyCode: keyCode, flags: event.flags) {
                stateLock.withLock { swallowingSpaceUp = true }
                if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    switchInputSource(trigger: trigger, at: timestamp)
                }
                return nil
            }
            return guarded(type: type, event: event, timestamp: timestamp)

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let swallow = stateLock.withLock { () -> Bool in
                guard swallowingSpaceUp, keyCode == InstantInputSwitchSupport.spaceKeyCode else { return false }
                swallowingSpaceUp = false
                return true
            }
            if swallow { return nil }
            return guarded(type: type, event: event, timestamp: timestamp)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func guarded(type: CGEventType, event: CGEvent, timestamp: UInt64) -> Unmanaged<CGEvent>? {
        // This tap sits ahead of the Super key's, so a Super key chord does
        // not carry its modifiers yet: it is a shortcut all the same.
        let superKeyHeld = SuperKeyService.isEngaged && SuperKeyService.shared.isHeld
        return inputGuard.process(type: type, event: event, timestamp: timestamp,
                                  rewriteAllowed: !superKeyHeld)
            ? Unmanaged.passUnretained(event) : nil
    }

    // MARK: - Switching

    private func switchInputSource(trigger: InstantInputSwitchTrigger, at timestamp: UInt64) {
        // Keys held from an earlier switch were typed for that source; they
        // go out (stamped with its layout) before this one changes it again.
        inputGuard.flush(endingWindow: true)
        let started = Self.nowNanoseconds()
        // Control-Space keeps its macOS meaning: back to the previous source.
        // The other keys go on through the list.
        let order: InputSourceSwitcher.Order = trigger == .controlSpace
            ? .previous(recentIDs: { InputSourceRecentsTracker.shared.ids })
            : .next
        guard let selection = InputSourceSwitcher.select(order) else {
            Self.log.notice("trigger \(trigger.rawValue, privacy: .public): nothing to switch to")
            return
        }
        // A stop that ran while the main thread selected must not inherit a
        // window: its flush timer would land on a run loop that is going away.
        guard !lifecycleLock.withLock({ shouldStopTapThread }) else { return }
        let selectMilliseconds = (Self.nowNanoseconds() - started) / 1_000_000
        // Recorded at once: a second press before macOS's notice arrives must
        // already go back from the new source.
        InputSourceRecentsTracker.shared.switched(from: selection.previousID, to: selection.id)
        let settings = InputSourceGuard.Settings.current()
        let strategy = inputGuard.arm(for: selection, at: timestamp, settings: settings)
        stateLock.withLock { switchedAtNanoseconds = started }
        Self.log.notice("trigger \(trigger.rawValue, privacy: .public) -> \(selection.id, privacy: .public) selected in \(selectMilliseconds, privacy: .public) ms; guard \(strategy?.rawValue ?? "off", privacy: .public) \(settings.milliseconds, privacy: .public) ms")
    }

    // MARK: - Helpers

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private static func nowNanoseconds() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }
}

/// The language indicator macOS shows next to the text cursor after every
/// input source switch (since macOS 14). It has no switch in System Settings;
/// this is the global `TSMLanguageIndicatorEnabled` preference that
/// `defaults write -g` would set. macOS reads it at login.
enum SystemLanguageIndicator {
    private static let key = "TSMLanguageIndicatorEnabled" as CFString

    /// Unset means macOS's default, which is on. A value written for this
    /// Mac only (`defaults -currentHost`) wins over the one for every Mac.
    static var isEnabled: Bool {
        synchronize()
        for host in [kCFPreferencesCurrentHost, kCFPreferencesAnyHost] {
            if let value = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication,
                                                  kCFPreferencesCurrentUser, host) as? Bool {
                return value
            }
        }
        return true
    }

    /// Off writes false; on removes the key, handing the choice back to
    /// macOS's default rather than pinning it. A this-Mac-only value is
    /// always cleared, so it cannot quietly outvote the choice made here.
    static func setEnabled(_ enabled: Bool) {
        CFPreferencesSetValue(key, nil, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSetValue(key, enabled ? nil : kCFBooleanFalse, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        synchronize()
    }

    private static func synchronize() {
        for host in [kCFPreferencesCurrentHost, kCFPreferencesAnyHost] {
            CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, host)
        }
    }
}
