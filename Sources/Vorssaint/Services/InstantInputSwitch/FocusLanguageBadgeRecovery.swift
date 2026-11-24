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

    /// Writes down a mode about to be set on an app, and says whether it
    /// did: a mode that could not be written down must not be set, or
    /// nothing would ever switch it back.
    static func record(pid: pid_t, mode: FocusLanguageBadgeSupport.AssistedApp.Mode) -> Bool {
        guard let launched = launchTime(of: pid) else { return false }
        var entries = load().filter { !($0.pid == pid && $0.mode == mode) }
        entries.append(Entry(pid: pid, launched: launched, mode: mode))
        save(entries)
        return true
    }

    /// Drops an app that has quit: its modes went with it.
    static func forget(pid: pid_t) {
        let entries = load()
        let kept = entries.filter { $0.pid != pid }
        if kept.count != entries.count { save(kept) }
    }

    /// Switches every recorded mode back off in the process it was set on.
    /// An entry leaves the record once its app is back, has quit, or its pid
    /// belongs to another process now; one whose app could not be switched
    /// back (busy past the timeout) stays for the next try. Without
    /// Accessibility nothing can be switched back, so the record is kept
    /// whole: it is the only way back for those apps.
    static func restorePending() {
        guard AXIsProcessTrusted() else { return }
        let left = load().filter { entry in
            guard entry.isSameProcess(launchedAt: launchTime(of: entry.pid)) else { return false }
            let application = AXUIElementCreateApplication(entry.pid)
            AXUIElementSetMessagingTimeout(application, messagingTimeout)
            let attribute = attribute(for: entry.mode)
            _ = AXUIElementSetAttributeValue(application, attribute, kCFBooleanFalse)
            // Setting reports cannotComplete even when it takes effect, so
            // only the read-back counts; an app that cannot say is taken as
            // done rather than retried forever.
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, attribute, &value) == .success else { return false }
            return (value as? Bool) == true
        }
        save(left)
    }

    static func attribute(for mode: FocusLanguageBadgeSupport.AssistedApp.Mode) -> CFString {
        switch mode {
        case .enhanced: return "AXEnhancedUserInterface" as CFString
        case .manual: return "AXManualAccessibility" as CFString
        }
    }

    // MARK: - Storage

    /// When the process started, from the kernel: LaunchServices knows no
    /// launch date for an app started another way (`code` from a terminal,
    /// Firefox from its binary), the kernel always does.
    private static func launchTime(of pid: pid_t) -> Double? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&name, u_int(name.count), &info, &size, nil, 0) == 0, size > 0,
              info.kp_proc.p_pid == pid else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        return Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
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
