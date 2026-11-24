// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import AppKit
import Carbon.HIToolbox
import os

/// EXPERIMENT. A switch made from outside the app leaves a Japanese, Chinese
/// or Korean input method running in it: macOS reports the new source, but
/// the app goes on typing through the method, and with the method's own
/// keyboard layout (KANA for kana typing, ABC while Control is down). The
/// Input menu gets this right because the app gives the method up before the
/// switch. A Chromium app (Cursor, VS Code, Chrome) gives it up only when it
/// stops being the active app; a panel that merely takes the key focus is
/// not enough, the method comes back with the focus.
///
/// So a switch that leaves an input method is led by a moment in which
/// UnTangle is the active app, the way macism does it: UnTangle activates
/// with a tiny invisible panel as its key window, the switch is made, and
/// once this process sees the new source the app that was in front gets the
/// activation back and takes the new source up.
///
/// The tap thread that switches waits through the lead, so no key arrives
/// meanwhile; keys typed after the switch, while UnTangle is still in front,
/// are held by the first-letter guard (`Settings.holdingThroughNudge()`) and
/// replayed once the app is back. Off by default; turned on with
/// `defaults write <bundle id> inputSourceFocusNudge activate`.
enum InputSourceFocusNudge {
    enum Mode: String {
        case off
        case activate
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "InstantInputSwitch")
    /// How long UnTangle stays in front before the switch, for the app to
    /// give its input method up.
    private static let lead: TimeInterval = 0.03
    /// How long it stays in front once this process sees the new source.
    private static let hold: TimeInterval = 0.03
    /// The longest it waits for this process to hear of the switch. The
    /// guard's hold (`Settings.nudgeMilliseconds`) outlasts this plus `hold`
    /// and the way back.
    private static let waitForNotice: TimeInterval = 0.1

    // Main thread only.
    private static var panel: NudgePanel?
    /// Bumped by every nudge, so only the last one hands the activation back.
    private static var generation: UInt = 0
    /// The source the release waits for, until this process sees it.
    private static var pendingID: String?
    /// The app the activation was taken from, until it gets it back.
    private static var returnTo: NSRunningApplication?
    private static var changeObserver: NSObjectProtocol?

    /// Any thread: whether a switch leaving an input method is led by a nudge.
    static var isEnabled: Bool { mode == .activate }

    /// Main thread, inside the switch, before selecting: brings UnTangle in
    /// front and waits for the app to let go of its input method.
    static func takeFocusBeforeSwitch() {
        generation &+= 1
        pendingID = nil
        // The panel goes up on this Space first: activating an app whose
        // only window is elsewhere (Settings on another desktop) would take
        // the person to that Space.
        let panel = ensurePanel()
        panel.orderFrontRegardless()
        panel.makeKey()
        // A nudge still waiting to hand back keeps the app it took from:
        // UnTangle itself is in front now.
        if returnTo == nil, let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            returnTo = front
            ActivationHandoff.activateBriefly()
        }
        log.notice("focus nudge: UnTangle in front for the switch")
        Thread.sleep(forTimeInterval: lead)
    }

    /// Main thread, after the switch to `id` (nil when it failed) and after
    /// the owner armed its guard: hands the activation back once this
    /// process, too, sees `id` as the current source, at once on a failure.
    static func release(to id: String?) {
        observeChanges()
        generation &+= 1
        let ours = generation
        guard let id else {
            finish(generation: ours, heard: true)
            return
        }
        pendingID = id
        if InputSourceSelection.currentSourceID() == id {
            settle(generation: ours, heard: true)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + waitForNotice) {
            settle(generation: ours, heard: false)
        }
    }

    private static func observeChanges() {
        guard changeObserver == nil else { return }
        changeObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { _ in
            guard let id = pendingID else { return }
            let ours = generation
            // The process's own view catches up as the notice is delivered;
            // a turn later it has.
            DispatchQueue.main.async {
                guard InputSourceSelection.currentSourceID() == id else { return }
                settle(generation: ours, heard: true)
            }
        }
    }

    /// The new source is in: the app gets the activation back after `hold`.
    private static func settle(generation ours: UInt, heard: Bool) {
        guard generation == ours, pendingID != nil else { return }
        pendingID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
            finish(generation: ours, heard: heard)
        }
    }

    private static func finish(generation ours: UInt, heard: Bool) {
        // A later nudge owns the activation now; it hands it back itself.
        guard generation == ours else { return }
        panel?.orderOut(nil)
        guard let app = returnTo else { return }
        returnTo = nil
        // Someone picked another app meanwhile (or UnTangle never got in
        // front): that one keeps the activation.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier else {
            log.notice("focus nudge: another app is in front, nothing handed back")
            return
        }
        ActivationHandoff.yield(to: app)
        if !app.activate(from: NSRunningApplication.current, options: []) {
            app.activate(options: [])
        }
        log.notice("focus nudge: handed back\(heard ? "" : " without the change notice", privacy: .public)")
    }

    private static var mode: Mode {
        Mode(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.inputSourceFocusNudge) ?? "") ?? .off
    }

    private static func ensurePanel() -> NudgePanel {
        if let panel { return panel }
        let made = NudgePanel(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        made.isOpaque = false
        made.backgroundColor = .clear
        made.hasShadow = false
        made.ignoresMouseEvents = true
        made.level = .statusBar
        made.hidesOnDeactivate = false
        made.isReleasedWhenClosed = false
        made.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel = made
        return made
    }
}

/// A borderless panel that may take the key focus.
private final class NudgePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
