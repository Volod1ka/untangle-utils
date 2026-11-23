// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os
import SwiftUI

/// Shows the input source now typing next to the text cursor whenever a text
/// field takes the focus, by a click, Tab or coming back to an app. Part of
/// Instant input switch, but with its own switch: it works with the switch
/// itself off, and with or without macOS's own indicator.
///
/// Only the frontmost app is watched, through Accessibility's focus
/// notification. Every Accessibility call runs on a queue of its own with a
/// timeout, so a busy app can never hold the main thread, and with it the
/// event taps that run there.
///
/// What each focus move found (the app, the element's role, where the badge
/// went) is logged under the "FocusLanguageBadge" category, never any text.
final class FocusLanguageBadgeService {
    static let shared = FocusLanguageBadgeService()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "FocusLanguageBadge")
    /// How long an app may take to answer one Accessibility call. Off the
    /// main thread this only delays the badge, and a web page building its
    /// accessibility tree for the first time can take a good part of it.
    private static let messagingTimeout: Float = 1.0
    // Both modes below are set only on apps that carry a web engine, are
    // recorded by FocusLanguageBadgeRecovery, and are switched back off when
    // the badge goes off. An app in either mode keeps its description up to
    // date for as long as it runs, which costs it some energy.
    /// Electron apps describe their web content only to assistive apps that
    /// ask with this attribute.
    private static let manualAccessibilityAttribute = FocusLanguageBadgeRecovery.attribute(for: .manual)
    /// What VoiceOver sets. Firefox and Chromium browsers describe web pages
    /// only once it is on, so it is set only when such an app answers with a
    /// bare window. The window features already step around it when they
    /// move such an app's windows.
    private static let enhancedUserInterfaceAttribute = FocusLanguageBadgeRecovery.attribute(for: .enhanced)
    /// The longest the app waits, when quitting, for apps to be handed back.
    private static let cleanupWait: TimeInterval = 2.5
    /// How long an app switched into assistive mode gets to describe itself
    /// before the focus is read again.
    private static let assistiveModeSettle: TimeInterval = 0.5
    /// How long the badge stays up.
    private static let visibleSeconds: TimeInterval = 1.4
    /// An app coming to the front may switch the input source to its own
    /// (System Settings › Keyboard › Input Sources › Automatically switch),
    /// and this process only sees that once the change notice arrives.
    private static let readDelay: TimeInterval = 0.06

    // Accessibility state, owned by axQueue, which recovery shares.
    private let axQueue = FocusLanguageBadgeRecovery.queue
    private var observer: AXObserver?
    private var observedApplication: AXUIElement?
    private var observedPID: pid_t = 0
    /// Apps already considered for each mode in this run, whatever came of
    /// it, so an app that refused, or was put there by something else, is
    /// not asked again on every focus move. Cleared for an app that quits.
    private var consideredForEnhanced: Set<pid_t> = []
    private var consideredForManual: Set<pid_t> = []
    /// Bundle path → whether it carries a web engine.
    private var webEngineBundles: [String: Bool] = [:]
    private var memory = FocusLanguageBadgeSupport.FocusMemory<AXUIElement>()

    // Main thread only.
    private var running = false
    /// Bumped on every start and stop, so work queued for an earlier run is
    /// dropped instead of showing a badge after the switch went off.
    private var epoch: UInt = 0
    /// Bumped on every move of the focus, so a badge waiting out
    /// `readDelay` never shows for a field the focus already left.
    private var focusSerial: UInt = 0
    private var activationToken: NSObjectProtocol?
    private var terminationToken: NSObjectProtocol?
    private var inputSourceObserver: NSObjectProtocol?
    private var panel: NSPanel?
    private var anchor: CGRect?
    private var hideWork: DispatchWorkItem?

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    // MARK: - Preferences

    func syncWithPreferences() {
        runOnMain {
            let wanted = AppFeature.instantInputSwitch.isAvailable
                && UserDefaults.standard.bool(forKey: DefaultsKey.instantInputSwitchFocusBadge)
            let shouldRun = SessionActivitySupport.tapShouldRun(featureWanted: wanted,
                                                                accessibilityGranted: AXIsProcessTrusted(),
                                                                sessionIsActive: SessionActivity.shared.isActive)
            if shouldRun { self.start() } else { self.stop() }
        }
    }

    /// Stops, for Cleaning Mode and the like, without waiting: the apps are
    /// handed back on the queue. Before the app quits or resets its
    /// permissions, `waitForCleanup` waits for that, a bounded time, so the
    /// main thread is never held for long; anything left is handed back by
    /// the next launch.
    func suspend(waitForCleanup: Bool = false) {
        runOnMain {
            self.stop()
            guard waitForCleanup else { return }
            let done = DispatchSemaphore(value: 0)
            self.axQueue.async {
                self.leaveAssistiveMode()
                done.signal()
            }
            _ = done.wait(timeout: .now() + Self.cleanupWait)
        }
    }

    // MARK: - Lifecycle (main thread)

    private func start() {
        guard !running else { return }
        running = true
        epoch &+= 1

        activationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.watch(app.processIdentifier, announce: true)
        }
        terminationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            self.axQueue.async { self.forget(pid) }
        }
        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in self?.inputSourceDidChange() }

        // The app in front when the switch goes on is usually UnTangle's own
        // Settings; whatever it is, nothing new took the focus yet.
        if let front = NSWorkspace.shared.frontmostApplication {
            watch(front.processIdentifier, announce: false)
        }
    }

    private func stop() {
        guard running else { return }
        running = false
        epoch &+= 1
        if let activationToken { NSWorkspace.shared.notificationCenter.removeObserver(activationToken) }
        if let terminationToken { NSWorkspace.shared.notificationCenter.removeObserver(terminationToken) }
        if let inputSourceObserver { DistributedNotificationCenter.default().removeObserver(inputSourceObserver) }
        activationToken = nil
        terminationToken = nil
        inputSourceObserver = nil
        axQueue.async {
            self.unwatch()
            self.leaveAssistiveMode()
        }
        hide(animated: false)
    }

    private func watch(_ pid: pid_t, announce: Bool, attempt: Int = 0) {
        guard running else { return }
        let epoch = self.epoch
        axQueue.async { self.attach(pid, announce: announce, epoch: epoch, attempt: attempt) }
    }

    /// An app that has only just launched comes to the front before its
    /// Accessibility side answers. It is asked again on a growing delay for
    /// as long as it stays in front.
    private static let attachRetryDelays: [TimeInterval] = [0.15, 0.4, 1.0, 2.5]

    private func retryWatch(_ pid: pid_t, announce: Bool, epoch: UInt, attempt: Int) {
        guard attempt < Self.attachRetryDelays.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.attachRetryDelays[attempt]) {
            guard self.running, self.epoch == epoch,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
            self.watch(pid, announce: announce, attempt: attempt + 1)
        }
    }

    /// What one move of the focus asks of the badge.
    private enum FocusOutcome {
        case show(CGRect)
        case hide
        /// The focus stayed where it was: whatever is up stays up.
        case keep
    }

    /// Applies the outcomes in the order the queue produced them. Every
    /// move bumps `focusSerial`, so a show still waiting for `readDelay` is
    /// dropped once the focus moves on.
    private func apply(_ outcome: FocusOutcome, epoch: UInt) {
        DispatchQueue.main.async {
            guard self.running, self.epoch == epoch else { return }
            switch outcome {
            case .keep:
                return
            case .hide:
                self.focusSerial &+= 1
                self.hide(animated: true)
            case .show(let anchor):
                self.focusSerial &+= 1
                let serial = self.focusSerial
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.readDelay) {
                    guard self.running, self.epoch == epoch, self.focusSerial == serial else { return }
                    self.show(under: anchor)
                }
            }
        }
    }

    /// From the observer's callback, on the main run loop.
    fileprivate func focusDidMove(to element: AXUIElement) {
        guard running else { return }
        let epoch = self.epoch
        axQueue.async { self.evaluate(self.currentFocus() ?? element, epoch: epoch) }
    }

    // MARK: - Accessibility (axQueue)

    private func attach(_ pid: pid_t, announce: Bool, epoch: UInt, attempt: Int) {
        unwatch()
        // Another app is in front now: a badge left from the last one goes.
        if announce { apply(.hide, epoch: epoch) }
        // UnTangle's own windows are left alone: its Settings are where the
        // switch is turned on, not where the badge is needed.
        guard pid > 0, pid != getpid() else { return }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, Self.messagingTimeout)
        // The result says little: some apps report an error for a value they
        // did take. An app already asked by someone else is left as it is.
        if !consideredForManual.contains(pid), embedsWebEngine(pid) {
            consideredForManual.insert(pid)
            if !Self.bool(application, Self.manualAccessibilityAttribute),
               FocusLanguageBadgeRecovery.record(pid: pid, mode: .manual) {
                _ = AXUIElementSetAttributeValue(application, Self.manualAccessibilityAttribute, kCFBooleanTrue)
            }
        }

        var created: AXObserver?
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverCreate(pid, focusCallback, &created) == .success, let created,
              AXObserverAddNotification(created, application,
                                        kAXFocusedUIElementChangedNotification as CFString, refcon) == .success
        else {
            Self.log.notice("pid \(pid, privacy: .public): focus watch failed, attempt \(attempt, privacy: .public)")
            DispatchQueue.main.async {
                self.retryWatch(pid, announce: announce, epoch: epoch, attempt: attempt)
            }
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedApplication = application
        observedPID = pid
        Self.log.notice("pid \(pid, privacy: .public): watching focus")

        guard let focused = Self.element(application, kAXFocusedUIElementAttribute) else { return }
        if announce {
            evaluate(focused, epoch: epoch)
        } else {
            _ = memory.focusMoved(to: focused, isTextInput: false)
            assistIfHidden(role: Self.string(focused, kAXRoleAttribute), announce: false, epoch: epoch)
        }
    }

    private func unwatch() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            if let observedApplication {
                AXObserverRemoveNotification(observer, observedApplication,
                                             kAXFocusedUIElementChangedNotification as CFString)
            }
        }
        observer = nil
        observedApplication = nil
        observedPID = 0
        memory.reset()
    }

    /// What the watched app says has the focus now. A notification's own
    /// element can be stale or the window itself (Terminal names its window
    /// right after its text view), so the app is asked again.
    private func currentFocus() -> AXUIElement? {
        guard let observedApplication else { return nil }
        return Self.element(observedApplication, kAXFocusedUIElementAttribute)
    }

    /// When the watched app names its bare window as the focus and carries
    /// a web engine, switches it into assistive mode once per run, then reads
    /// the focus again after the app had a moment to describe its content.
    /// Checked on every focus move, not only when the app comes to the front:
    /// a browser that arrives with its address bar focused still shows the
    /// window once a page takes the focus. With `announce` off (the switch
    /// just went on) the second read only notes the focus, so no badge shows
    /// for a field nobody just moved to.
    private func assistIfHidden(role: String?, announce: Bool, epoch: UInt) {
        let pid = observedPID
        guard FocusLanguageBadgeSupport.hidesItsContent(focusedRole: role),
              let application = observedApplication,
              !consideredForEnhanced.contains(pid), embedsWebEngine(pid) else { return }
        consideredForEnhanced.insert(pid)
        // One put there by something else (VoiceOver) is left as it is.
        guard !Self.bool(application, Self.enhancedUserInterfaceAttribute) else {
            Self.log.notice("pid \(pid, privacy: .public) shows only its window; already in assistive mode")
            return
        }
        guard FocusLanguageBadgeRecovery.record(pid: pid, mode: .enhanced) else {
            Self.log.notice("pid \(pid, privacy: .public) shows only its window; not switched, its start time is unknown")
            return
        }
        // Setting it reports cannotComplete even when it takes effect, so
        // only the read-back counts.
        _ = AXUIElementSetAttributeValue(application, Self.enhancedUserInterfaceAttribute, kCFBooleanTrue)
        let entered = Self.bool(application, Self.enhancedUserInterfaceAttribute)
        Self.log.notice("pid \(pid, privacy: .public) shows only its window; assistive mode \(entered ? "on" : "refused", privacy: .public)")
        guard entered else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.assistiveModeSettle) {
            guard self.running, self.epoch == epoch else { return }
            self.axQueue.async {
                guard self.observedPID == pid, let focused = self.currentFocus() else { return }
                if announce {
                    self.evaluate(focused, epoch: epoch)
                } else {
                    _ = self.memory.focusMoved(to: focused, isTextInput: false)
                }
            }
        }
    }

    /// Hands every app back the way it was found, through the record, which
    /// also skips a pid a new process has taken since.
    private func leaveAssistiveMode() {
        FocusLanguageBadgeRecovery.restorePending()
        consideredForEnhanced.removeAll()
        consideredForManual.removeAll()
    }

    /// An app that quit took its modes with it.
    private func forget(_ pid: pid_t) {
        consideredForEnhanced.remove(pid)
        consideredForManual.remove(pid)
        FocusLanguageBadgeRecovery.forget(pid: pid)
    }

    private func embedsWebEngine(_ pid: pid_t) -> Bool {
        guard let bundle = NSRunningApplication(processIdentifier: pid)?.bundleURL else { return false }
        if let known = webEngineBundles[bundle.path] { return known }
        let files = FileManager.default
        let contents = bundle.appendingPathComponent("Contents")
        let frameworksURL = contents.appendingPathComponent("Frameworks")
        let found = FocusLanguageBadgeSupport.embedsWebEngine(
            executables: (try? files.contentsOfDirectory(atPath: contents.appendingPathComponent("MacOS").path)) ?? [],
            frameworks: (try? files.contentsOfDirectory(atPath: frameworksURL.path)) ?? [],
            frameworkHasHelpers: { name in
                files.fileExists(atPath: frameworksURL
                    .appendingPathComponent(name).appendingPathComponent("Versions/Current/Helpers").path)
            })
        webEngineBundles[bundle.path] = found
        return found
    }

    private func evaluate(_ element: AXUIElement, epoch: UInt) {
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        let role = Self.string(element, kAXRoleAttribute)
        let isText = FocusLanguageBadgeSupport.isTextInput(role: role)
        guard memory.focusMoved(to: element, isTextInput: isText) else {
            if !isText {
                // The subrole is read only when debug logging is on: the
                // message's arguments are evaluated lazily.
                Self.log.debug("focus on \(role ?? "no role", privacy: .public)/\(Self.string(element, kAXSubroleAttribute) ?? "-", privacy: .public): not a text field")
                assistIfHidden(role: role, announce: true, epoch: epoch)
            }
            apply(isText ? .keep : .hide, epoch: epoch)
            return
        }
        // A field with nowhere to put the badge still took the focus, so a
        // badge left under the previous one goes.
        let caret = Self.caretBounds(element)
        let field = Self.frame(element)
        let anchor = FocusLanguageBadgeSupport.anchor(caret: caret, field: field)
        // Geometry only, in Accessibility's space: never what is typed.
        Self.log.notice("focus on \(role ?? "no role", privacy: .public): badge \(anchor?.source.rawValue ?? "not shown, no geometry", privacy: .public); caret \(Self.describe(caret), privacy: .public), field \(Self.describe(field), privacy: .public)")
        apply(anchor.map { .show($0.rect) } ?? .hide, epoch: epoch)
    }

    // MARK: - Badge (main thread)

    private func show(under anchor: CGRect) {
        guard let reading = InputSourceSelection.currentReading() else { return }
        self.anchor = anchor
        let panel = ensurePanel()
        let host = NSHostingView(rootView: FocusLanguageBadgeView(code: reading.code, name: reading.name))
        let size = host.fittingSize
        panel.contentView = host

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        // Whole screens, like macOS's own indicator: a field just above the
        // Dock keeps the badge under its caret, drawn over the Dock.
        let screens = NSScreen.screens.map {
            FocusLanguageBadgeSupport.flipped($0.frame, primaryHeight: primaryHeight)
        }
        let origin = FocusLanguageBadgeSupport.origin(for: size, under: anchor, screens: screens)
        let frame = FocusLanguageBadgeSupport.flipped(CGRect(origin: origin, size: size),
                                                      primaryHeight: primaryHeight)
        panel.setFrame(frame, display: true)
        Self.log.notice("badge at \(Self.describe(CGRect(origin: origin, size: size)), privacy: .public) under \(Self.describe(anchor), privacy: .public); screens \(screens.map { Self.describe($0) }.joined(separator: " "), privacy: .public)")

        if !panel.isVisible || panel.alphaValue < 1 {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide(animated: true) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleSeconds, execute: work)
    }

    /// A switch while the badge is up shows the new language in its place.
    private func inputSourceDidChange() {
        guard running, let anchor, panel?.isVisible == true, hideWork != nil else { return }
        show(under: anchor)
    }

    private func hide(animated: Bool) {
        hideWork?.cancel()
        hideWork = nil
        anchor = nil
        guard let panel, panel.isVisible else { return }
        guard animated else {
            panel.orderOut(nil)
            panel.contentView = nil
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // A badge shown again while this one faded keeps its panel.
            guard let self, self.hideWork == nil else { return }
            panel.orderOut(nil)
            panel.contentView = nil
        })
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = OverlayPanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.panel = panel
        return panel
    }

    // MARK: - Helpers

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    /// A related element, with the same short timeout as every other: an
    /// element starts out with the system's own, which is several seconds.
    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let found = value as! AXUIElement
        AXUIElementSetMessagingTimeout(found, messagingTimeout)
        return found
    }

    private static func describe(_ rect: CGRect?) -> String {
        guard let rect else { return "none" }
        // Formatted, not converted to Int: an app can report values no Int holds.
        // A log line, so no region's digits: the same text on every Mac.
        return String(format: "(%.0f,%.0f %.0f×%.0f)", locale: nil,
                      rect.minX, rect.minY, rect.width, rect.height)
    }

    private static func bool(_ element: AXUIElement, _ attribute: CFString) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return false }
        return (value as? Bool) == true
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard let position = axValue(element, kAXPositionAttribute),
              let extent = axValue(element, kAXSizeAttribute),
              AXValueGetValue(position, .cgPoint, &origin),
              AXValueGetValue(extent, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// The insertion point's bounds, measured by the app itself: the
    /// selection collapsed to where it starts, or a character beside it when
    /// the app measures nothing for an empty range.
    private static func caretBounds(_ element: AXUIElement) -> CGRect? {
        var range = CFRange()
        guard let selection = axValue(element, kAXSelectedTextRangeAttribute),
              AXValueGetValue(selection, .cfRange, &range), range.location >= 0 else { return nil }
        let collapsed = bounds(element, CFRange(location: range.location, length: 0))
        if let collapsed, FocusLanguageBadgeSupport.caret(collapsed: collapsed, before: nil, after: nil) != nil {
            return collapsed
        }
        let before = range.location > 0 ? bounds(element, CFRange(location: range.location - 1, length: 1)) : nil
        let after = before == nil ? bounds(element, CFRange(location: range.location, length: 1)) : nil
        return FocusLanguageBadgeSupport.caret(collapsed: collapsed, before: before, after: after)
    }

    private static func bounds(_ element: AXUIElement, _ range: CFRange) -> CGRect? {
        var range = range
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element,
                                                         kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         parameter, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }
}

private let focusCallback: AXObserverCallback = { _, element, _, refcon in
    guard let refcon else { return }
    Unmanaged<FocusLanguageBadgeService>.fromOpaque(refcon).takeUnretainedValue().focusDidMove(to: element)
}

/// The badge: the language's short code on the accent color, then the name
/// the Input menu shows, so two layouts of one language still read apart.
private struct FocusLanguageBadgeView: View {
    let code: String
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            if !code.isEmpty {
                Text(code)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.97),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .padding(1)
        .fixedSize()
    }
}
