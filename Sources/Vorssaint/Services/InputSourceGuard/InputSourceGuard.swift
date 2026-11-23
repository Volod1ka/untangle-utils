// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Selecting an enabled input source from a keyboard tap.
enum InputSourceSwitcher {
    enum Order {
        /// On through the enabled sources, in the order the Input menu shows.
        case next
        /// Back to the source used before the current one, like macOS's own
        /// Control-Space. The list is read on the main thread at switch time.
        case previous(recentIDs: () -> [String])
    }

    /// The source just selected, as the first-letter guard needs it.
    struct Selection {
        let id: String
        let name: String
        /// Nil for an input method, which has no layout to translate through.
        let layout: Data?
        let keyboardType: UInt32
        /// The source that was selected before this switch.
        var previousID: String? = nil
    }

    /// This process's last switch, to see through a stale report of the
    /// source it just left. Main thread only, like every TIS call here.
    private static var lastSwitch: InputSourceGuardSupport.LastSwitch?
    /// Marks `lastSwitch` confirmed when macOS's notice arrives. Main only.
    private static var changeObserver: NSObjectProtocol?

    private static func observeChanges() {
        guard changeObserver == nil else { return }
        changeObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { _ in lastSwitch?.confirmed = true }
    }

    /// Selects the next source in `order` before the tap lets the next key go.
    /// TIS talks to the text input server from the main thread, so a tap
    /// thread waits for it there: hopping asynchronously would let the key
    /// already in flight reach the app first. Selecting directly also lets an
    /// input method commit or cancel on its own, the way the Input menu does.
    static func select(_ order: Order) -> Selection? {
        let select = { () -> Selection? in
            let sources = InputSourceSelection.selectableInputSources()
            let ids = sources.compactMap {
                InputSourceSelection.inputSourceString($0, property: kTISPropertyInputSourceID)
            }
            observeChanges()
            let now = ProcessInfo.processInfo.systemUptime
            let reported = InputSourceSelection.currentSourceID()
            let currentID = InputSourceGuardSupport.effectiveCurrentID(
                reported: reported, lastSwitch: lastSwitch, now: now)
            let target: String?
            switch order {
            case .next:
                target = SuperKeySupport.nextInputSourceID(currentID: currentID, enabledIDs: ids)
            case .previous(let recentIDs):
                target = InputSourceGuardSupport.previousSourceID(currentID: currentID, enabledIDs: ids,
                                                                  recentIDs: recentIDs())
            }
            guard let nextID = target,
                  let next = sources.first(where: {
                      InputSourceSelection.inputSourceString($0, property: kTISPropertyInputSourceID) == nextID
                  }),
                  TISSelectInputSource(next) == noErr
            else { return nil }
            lastSwitch = InputSourceGuardSupport.LastSwitch(reported: reported, selected: nextID, at: now)
            let isLayout = InputSourceSelection.inputSourceString(next, property: kTISPropertyInputSourceType)
                == kTISTypeKeyboardLayout as String
            let layout = isLayout
                ? TISGetInputSourceProperty(next, kTISPropertyUnicodeKeyLayoutData).map {
                    Unmanaged<CFData>.fromOpaque($0).takeUnretainedValue() as Data
                }
                : nil
            return Selection(id: nextID,
                             name: InputSourceSelection.inputSourceString(next, property: kTISPropertyLocalizedName)
                                ?? nextID,
                             layout: layout,
                             keyboardType: UInt32(LMGetKbdType()),
                             previousID: currentID)
        }
        return Thread.isMainThread ? select() : DispatchQueue.main.sync(execute: select)
    }
}

/// Which way a switch goes from the current source.
enum InputSourceSwitchOrder: String, CaseIterable, Identifiable {
    /// Back to the source used before, like macOS's Control-Space: with
    /// three or more sources it goes back and forth between the last two.
    case previous
    /// On through the list, the way the Input menu orders it.
    case next

    var id: String { rawValue }

    static func sanitized(_ raw: String?) -> InputSourceSwitchOrder {
        raw.flatMap(InputSourceSwitchOrder.init(rawValue:)) ?? .next
    }
}

/// The recently used sources behind "previous", shared by every tap that
/// switches that way (Instant input switch's Control-Space, the Super key).
/// It follows macOS's change notice while anyone holds it; whoever starts
/// holding it after nobody did gets macOS's own history first, since macOS
/// kept counting while nothing here was listening.
final class InputSourceRecentsTracker {
    static let shared = InputSourceRecentsTracker()

    private let lock = NSLock()
    private var recents = InputSourceRecents()
    // Main thread only.
    private var holders: Set<String> = []
    private var observer: NSObjectProtocol?

    private init() {}

    /// Main thread. Idempotent for one holder.
    func hold(_ holding: Bool, for holder: String) {
        if holding {
            let wasIdle = holders.isEmpty
            holders.insert(holder)
            if wasIdle {
                seedFromSystem()
                observer = DistributedNotificationCenter.default().addObserver(
                    forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
                    object: nil, queue: .main
                ) { [weak self] _ in self?.noteCurrent() }
            }
            noteCurrent()
        } else if holders.remove(holder) != nil, holders.isEmpty, let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
        }
    }

    /// Any thread: the history, most recent first.
    var ids: [String] { lock.withLock { recents.ids } }

    /// Any thread: a switch made here, recorded at once, so a second press
    /// before macOS's notice arrives already goes back from the new source.
    func switched(from previous: String?, to id: String) {
        lock.withLock { recents.switched(from: previous, to: id) }
    }

    /// Every change counts, the Input menu's included.
    private func noteCurrent() {
        guard let current = InputSourceSelection.currentSourceID() else { return }
        lock.withLock { recents.noticed(current) }
    }

    private func seedFromSystem() {
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)
        let entries = CFPreferencesCopyAppValue("AppleInputSourceHistory" as CFString, domain)
            as? [[String: Any]] ?? []
        let sources = InputSourceSelection.selectableInputSources()
        let enabled = sources.compactMap {
            InputSourceSelection.inputSourceString($0, property: kTISPropertyInputSourceID)
        }
        var layoutNames: [String: String] = [:]
        if let nameKey = Self.keyLayoutNameProperty {
            for source in sources {
                guard let id = InputSourceSelection.inputSourceString(source, property: kTISPropertyInputSourceID),
                      let name = InputSourceSelection.inputSourceString(source, property: nameKey) else { continue }
                layoutNames[name] = id
            }
        }
        let history = InputSourceGuardSupport.historyIDs(entries, enabledIDs: enabled, layoutNames: layoutNames)
        lock.withLock { recents.seed(history) }
    }

    /// The layout's own name, the one macOS's history stores (U.S. for
    /// `com.apple.keylayout.US`). HIToolbox exports the key without declaring
    /// it, so it is looked up by name; without it the id is matched alone.
    private static let keyLayoutNameProperty: CFString? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "kTISPropertyKeyLayoutName") else {
            return nil
        }
        return symbol.assumingMemoryBound(to: CFString.self).pointee
    }()
}

/// Keeps the keys typed right after an input source switch in the new layout
/// (BETA). One per keyboard tap that switches sources; every call comes from
/// that tap's thread.
///
/// For a short window after a switch it either stamps every typing key with
/// the character the NEW layout produces (rewrite), or holds the keys back and
/// sends them again once the window has passed (replay). A switch to an input
/// method always replays. Shortcuts (and, where the owner sees both halves of
/// a click, clicks) during a replay window go out behind the held keys and end
/// the window, so nothing lands out of order.
final class InputSourceGuard {
    struct Settings: Equatable {
        var enabled = true
        var strategy = InputSourceGuardStrategy.rewrite
        var milliseconds = InputSourceGuardSupport.defaultMilliseconds

        static func current(_ defaults: UserDefaults = .standard) -> Settings {
            Settings(enabled: defaults.bool(forKey: DefaultsKey.inputSourceGuardEnabled),
                     strategy: InputSourceGuardStrategy.sanitized(
                        defaults.string(forKey: DefaultsKey.inputSourceGuardStrategy)),
                     milliseconds: InputSourceGuardSupport.sanitizedMilliseconds(
                        defaults.integer(forKey: DefaultsKey.inputSourceGuardMilliseconds)))
        }
    }

    enum Activity {
        case rewrote
        case replayed(keys: Int)
    }

    /// A replay window whose flush never came (its run loop went away) is
    /// given up this long after its deadline.
    private static let staleReplayNanoseconds: UInt64 = 1_000_000_000
    /// Replayed copies that have not come back through the tap by then are
    /// presumed lost (another tap dropped them, or this one was disabled by
    /// timeout), so ordering stops waiting for them.
    private static let lostReplayNanoseconds: UInt64 = 500_000_000

    private struct RewriteWindow {
        let deadline: UInt64
        var deadKeyState: UInt32 = 0
    }

    /// One held event, and whether a flush may stamp new-layout text on it:
    /// the owner's veto (a Super key chord) is taken when the key arrives.
    private struct HeldEvent {
        let event: CGEvent
        let stampable: Bool
    }

    private enum HoldDecision {
        case notHeld, held, heldAndFlush
    }

    private let marker: Int64
    /// True when the owner's tap sees mouse-ups as well as mouse-downs. Only
    /// then can a click be held: holding a down whose up goes on at once
    /// would hand the app the release before the press.
    private let holdsClicks: Bool
    private let onActivity: ((Activity) -> Void)?

    private let lock = NSLock()
    /// The layout the last switch selected; nil for an input method.
    private var targetLayout: Data?
    private var targetKeyboardType: UInt32 = 0
    private var rewriteWindow: RewriteWindow?
    /// Deadline of the open replay window, if one is open.
    private var replayDeadline: UInt64?
    /// Held events, in arrival order.
    private var replayQueue: [HeldEvent] = []
    /// Replayed copies posted but not yet seen coming back through the tap.
    /// While any are out, new events queue behind them so nothing overtakes.
    private var replayInFlight = 0
    private var replayPostedAt: UInt64 = 0
    /// Set while a watchdog is waiting to release events queued behind copies
    /// that may never come back.
    private var inFlightWatchdogArmed = false
    private var generation: UInt = 0

    /// `marker` tags this guard's replayed copies; it must be one that
    /// `OwnKeyEvent` knows, so other filters leave the copies alone.
    init(marker: Int64, holdsClicks: Bool, onActivity: ((Activity) -> Void)? = nil) {
        self.marker = marker
        self.holdsClicks = holdsClicks
        self.onActivity = onActivity
    }

    // MARK: - Owner calls

    /// Arms the window after a switch the owner just made, from its tap's
    /// thread. Returns the strategy in effect, or nil when the guard is off.
    /// The owner flushes before switching (`flush(endingWindow: true)`), so
    /// keys held for the previous source go out stamped with its layout.
    @discardableResult
    func arm(for selection: InputSourceSwitcher.Selection, at timestamp: UInt64,
             settings: Settings) -> InputSourceGuardStrategy? {
        let replays = settings.strategy == .replay || selection.layout == nil
        let deadline = timestamp &+ UInt64(settings.milliseconds) * 1_000_000
        let armed = lock.withLock { () -> UInt in
            targetLayout = selection.layout
            targetKeyboardType = selection.keyboardType
            rewriteWindow = settings.enabled && !replays ? RewriteWindow(deadline: deadline) : nil
            replayDeadline = settings.enabled && replays ? deadline : nil
            generation &+= 1
            return generation
        }
        guard settings.enabled else { return nil }
        if replays {
            schedule(after: Double(settings.milliseconds) / 1000) { [weak self] in
                guard let self, self.lock.withLock({ self.generation == armed }) else { return }
                self.flush(endingWindow: true)
            }
        }
        return replays ? .replay : .rewrite
    }

    /// True when `event` is one of this guard's replayed copies coming back
    /// through the tap. The owner lets it go on untouched.
    func absorbReplay(_ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.eventSourceUserData) == marker else { return false }
        let drain = lock.withLock { () -> Bool in
            if replayInFlight > 0 { replayInFlight -= 1 }
            return replayInFlight == 0 && replayDeadline == nil && !replayQueue.isEmpty
        }
        if drain { flush(endingWindow: false) }
        return true
    }

    /// Guards one event the owner is about to let through. False means the
    /// event was held and must be swallowed. `rewriteAllowed` lets the owner
    /// veto new-layout text (a Super key chord whose flags are not stamped yet).
    func process(type: CGEventType, event: CGEvent, timestamp: UInt64,
                 rewriteAllowed: Bool = true) -> Bool {
        // Snippets, Quit Protection and other keys the app types itself.
        if OwnKeyEvent.isPosted(event) { return true }
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // The text typed before a click belongs where it was typed.
            if holdsClicks { return !hold(event, timestamp: timestamp, endsWindow: true, stampable: false) }
            // Without the release in view the press cannot wait: what is
            // held goes out first and the click follows as it is.
            if lock.withLock({ replayDeadline != nil }) { flush(endingWindow: true) }
            return true
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return !holdsClicks || !hold(event, timestamp: timestamp, endsWindow: false, stampable: false)
        case .keyDown:
            // A shortcut goes out behind the held keys and ends the window,
            // so ⌘ is not released before its own key arrives.
            let isTyping = InputSourceGuardSupport.isTyping(flags: event.flags)
            if hold(event, timestamp: timestamp, endsWindow: !isTyping, stampable: rewriteAllowed && isTyping) {
                return false
            }
            if rewriteAllowed && isTyping { rewrite(event, timestamp: timestamp) }
            return true
        case .keyUp:
            return !hold(event, timestamp: timestamp, endsWindow: false, stampable: false)
        default:
            return true
        }
    }

    /// Sends the held events again, in order, stamped with the text the
    /// switched-to layout types where it has one: by the time an app reads
    /// them it may have switched again, and the stamp keeps them right.
    /// Owners call it from their tap thread, or after their tap is gone.
    func flush(endingWindow: Bool) {
        let (events, layout, keyboardType) = lock.withLock { () -> ([HeldEvent], Data?, UInt32) in
            if endingWindow { replayDeadline = nil }
            let held = replayQueue
            replayQueue.removeAll()
            replayInFlight += held.count
            replayPostedAt = Self.nowNanoseconds()
            return (held, targetLayout, targetKeyboardType)
        }
        guard !events.isEmpty else { return }
        var deadKeyState: UInt32 = 0
        var stamping = layout != nil
        for held in events {
            let event = held.event
            if stamping, held.stampable, event.type == .keyDown, let layout {
                let text = Self.translate(event, layout: layout, fallbackKeyboardType: keyboardType,
                                          deadKeyState: &deadKeyState)
                if let text {
                    Self.stamp(event, with: text)
                } else if deadKeyState != 0 {
                    // A dead key goes out unstamped, and so does the rest:
                    // stamping its partner with the composed character would
                    // type it twice in an app that composes on its own.
                    stamping = false
                }
            }
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.post(tap: .cghidEventTap)
        }
        onActivity?(.replayed(keys: events.filter { $0.event.type == .keyDown }.count))
    }

    /// A fresh tap starts from nothing: a window opened by a switch that
    /// finished while the previous tap was stopping, or copies posted into a
    /// tap that no longer exists, must not hold keys now.
    func reset() {
        lock.withLock {
            rewriteWindow = nil
            replayDeadline = nil
            replayQueue.removeAll()
            replayInFlight = 0
            inFlightWatchdogArmed = false
            generation &+= 1
        }
    }

    // MARK: - Replay

    /// Queues the event while a replay window is open or replayed copies are
    /// still on their way, so nothing overtakes the events already held.
    private func hold(_ event: CGEvent, timestamp: UInt64, endsWindow: Bool, stampable: Bool) -> Bool {
        var armWatchdog = false
        let decision = lock.withLock { () -> HoldDecision in
            if replayInFlight > 0, Self.nowNanoseconds() &- replayPostedAt > Self.lostReplayNanoseconds {
                replayInFlight = 0
            }
            guard replayDeadline != nil || replayInFlight > 0 || !replayQueue.isEmpty,
                  let copy = event.copy() else { return .notHeld }
            replayQueue.append(HeldEvent(event: copy, stampable: stampable))
            if let deadline = replayDeadline,
               endsWindow
                || replayQueue.count >= InputSourceGuardSupport.replayLimit
                // The flush timer never fired; let the window go now.
                || timestamp > deadline &+ Self.staleReplayNanoseconds {
                replayDeadline = nil
            }
            // With the window closed and nothing in flight, the queue only
            // waited for ordering: it can go now.
            if replayDeadline == nil && replayInFlight == 0 { return .heldAndFlush }
            // Waiting only on copies in flight: if they never come back, no
            // later key may come either, so a watchdog lets the queue go.
            if replayDeadline == nil && !inFlightWatchdogArmed {
                inFlightWatchdogArmed = true
                armWatchdog = true
            }
            return .held
        }
        if armWatchdog { scheduleInFlightWatchdog() }
        switch decision {
        case .notHeld: return false
        case .held: return true
        case .heldAndFlush:
            flush(endingWindow: false)
            return true
        }
    }

    private func scheduleInFlightWatchdog() {
        schedule(after: Double(Self.lostReplayNanoseconds) / 1_000_000_000) { [weak self] in
            guard let self else { return }
            let stuck = self.lock.withLock { () -> Bool in
                self.inFlightWatchdogArmed = false
                guard self.replayInFlight > 0, self.replayDeadline == nil, !self.replayQueue.isEmpty else {
                    return false
                }
                self.replayInFlight = 0
                return true
            }
            if stuck { self.flush(endingWindow: false) }
        }
    }

    /// Timers run on the tap's own run loop (the caller's), so they and the
    /// tap callbacks never interleave.
    private func schedule(after seconds: Double, _ work: @escaping () -> Void) {
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + seconds,
                                                    0, 0, 0) { _ in work() }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
    }

    // MARK: - Rewrite

    private func rewrite(_ event: CGEvent, timestamp: UInt64) {
        let text = lock.withLock { () -> String? in
            guard var window = rewriteWindow else { return nil }
            guard timestamp <= window.deadline else {
                rewriteWindow = nil
                return nil
            }
            guard let layout = targetLayout else { return nil }
            var deadKeyState = window.deadKeyState
            let text = Self.translate(event, layout: layout, fallbackKeyboardType: targetKeyboardType,
                                      deadKeyState: &deadKeyState)
            if text == nil && deadKeyState != 0 {
                // A dead key waits for the next one, inside an app that may
                // still be on the old layout. Out of reach for now: the rest
                // of this window is left to the app.
                rewriteWindow = nil
                return nil
            }
            window.deadKeyState = deadKeyState
            rewriteWindow = window
            return text
        }
        guard let text else { return }
        Self.stamp(event, with: text)
        onActivity?(.rewrote)
    }

    /// The visible text a key types in `layout`, or nil for a key that types
    /// none (or a dead key, which leaves `deadKeyState` set).
    private static func translate(_ event: CGEvent, layout: Data, fallbackKeyboardType: UInt32,
                                  deadKeyState: inout UInt32) -> String? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        // The keyboard that sent this key, so an ISO board beside an ANSI one
        // translates its own extra keys.
        let eventKeyboardType = UInt32(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeyboardType))
        let keyboardType = eventKeyboardType != 0 ? eventKeyboardType : fallbackKeyboardType
        var units = [UniChar](repeating: 0, count: 8)
        var length = 0
        let status = layout.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> OSStatus in
            guard let pointer = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(pointer, UInt16(truncatingIfNeeded: keyCode),
                                  UInt16(kUCKeyActionDown),
                                  InputSourceGuardSupport.translationModifierState(flags: event.flags),
                                  keyboardType, 0, &deadKeyState,
                                  units.count, &length, &units)
        }
        guard status == noErr else { return nil }
        return InputSourceGuardSupport.typedText(Array(units.prefix(length)))
    }

    private static func stamp(_ event: CGEvent, with text: String) {
        let units = Array(text.utf16)
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
    }

    private static func nowNanoseconds() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }
}
