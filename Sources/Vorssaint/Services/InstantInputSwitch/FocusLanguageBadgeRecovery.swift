// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import AppKit
import ApplicationServices

/// Keeps a written record of the apps the language badge switched into an
/// assistive mode, so they are switched back even when UnTangle never got
/// to do it itself: a crash, a force quit, or a quit right after the feature
/// was uninstalled. The next launch hands those apps back.
///
/// Everything runs on `queue`, which the badge service uses for all of its
/// Accessibility work too, so a recovery and a new run never overlap.
enum FocusLanguageBadgeRecovery {
    static let queue = DispatchQueue(label: "untangle.focusLanguageBadge", qos: .userInitiated)

    private typealias Entry = FocusLanguageBadgeSupport.AssistedApp
    private static let messagingTimeout: Float = 1.0

    /// Main thread or any: a plain read of the record.
    static func hasPendingEntries(in defaults: UserDefaults = .standard) -> Bool {
        !(defaults.array(forKey: DefaultsKey.instantInputSwitchFocusBadgeAssisted) ?? []).isEmpty
    }

    /// At launch: hands back what an earlier run left behind, off the main
    /// thread, and only when there is something to hand back.
    static func restoreAtStartup() {
        guard hasPendingEntries() else { return }
        queue.async { restorePending() }
    }

    // MARK: - On `queue`

    /// Writes down a mode just set on an app.
    static func record(pid: pid_t, mode: FocusLanguageBadgeSupport.AssistedApp.Mode) {
        guard let launched = launchTime(of: pid) else { return }
        var entries = load().filter { !($0.pid == pid && $0.mode == mode) }
        entries.append(Entry(pid: pid, launched: launched, mode: mode))
        save(entries)
    }

    /// Drops an app that has quit: its modes went with it.
    static func forget(pid: pid_t) {
        let entries = load()
        let kept = entries.filter { $0.pid != pid }
        if kept.count != entries.count { save(kept) }
    }

    /// Switches every recorded mode back off in the process it was set on,
    /// then clears the record. A pid now held by another process is left
    /// alone.
    static func restorePending() {
        for entry in load() where entry.isSameProcess(launchedAt: launchTime(of: entry.pid)) {
            let application = AXUIElementCreateApplication(entry.pid)
            AXUIElementSetMessagingTimeout(application, messagingTimeout)
            _ = AXUIElementSetAttributeValue(application, attribute(for: entry.mode), kCFBooleanFalse)
        }
        save([])
    }

    static func attribute(for mode: FocusLanguageBadgeSupport.AssistedApp.Mode) -> CFString {
        switch mode {
        case .enhanced: return "AXEnhancedUserInterface" as CFString
        case .manual: return "AXManualAccessibility" as CFString
        }
    }

    // MARK: - Storage

    private static func launchTime(of pid: pid_t) -> Double? {
        NSRunningApplication(processIdentifier: pid)?.launchDate?.timeIntervalSince1970
    }

    private static func load() -> [Entry] {
        let stored = UserDefaults.standard.array(forKey: DefaultsKey.instantInputSwitchFocusBadgeAssisted)
            as? [[String: Any]] ?? []
        return stored.compactMap(Entry.init(stored:))
    }

    private static func save(_ entries: [Entry]) {
        if entries.isEmpty {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.instantInputSwitchFocusBadgeAssisted)
        } else {
            UserDefaults.standard.set(entries.map(\.stored), forKey: DefaultsKey.instantInputSwitchFocusBadgeAssisted)
        }
    }
}
