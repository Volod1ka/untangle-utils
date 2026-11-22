// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import AppKit
import SwiftUI

struct InstantInputSwitchSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = InstantInputSwitchService.shared
    @AppStorage(DefaultsKey.instantInputSwitchEnabled) private var enabled = false
    @AppStorage(DefaultsKey.instantInputSwitchTrigger) private var triggerRaw =
        InstantInputSwitchTrigger.controlSpace.rawValue
    @AppStorage(DefaultsKey.inputSourceGuardEnabled) private var guardEnabled = true
    @AppStorage(DefaultsKey.inputSourceGuardStrategy) private var strategyRaw =
        InputSourceGuardStrategy.rewrite.rawValue
    @AppStorage(DefaultsKey.inputSourceGuardMilliseconds) private var guardMilliseconds =
        InputSourceGuardSupport.defaultMilliseconds
    @AppStorage(DefaultsKey.superKeyEnabled) private var superKeyEnabled = false
    @AppStorage(DefaultsKey.superKeySource) private var superKeySourceRaw = SuperKeySource.capsLock.rawValue

    /// Read from macOS on the way in, since it can change outside the app.
    @State private var languageIndicatorShown = true

    private var text: InstantInputSwitchStrings { FeatureStrings.instantInputSwitch(l10n.language) }
    private var trigger: InstantInputSwitchTrigger { InstantInputSwitchTrigger.sanitized(triggerRaw) }

    private var shadowedBySuperKey: Bool {
        AppFeature.superKey.isAvailable && superKeyEnabled
            && trigger.isShadowed(bySuperKeySource: SuperKeySource.sanitized(superKeySourceRaw))
    }

    var body: some View {
        Form {
            Section(text.pageTitle) {
                Toggle(text.enableToggle, isOn: $enabled)
                    .onChange(of: enabled) { _, value in
                        InstantInputSwitchService.shared.syncWithPreferences()
                        guard value, !permissions.accessibility else { return }
                        permissions.requestAccessibility()
                        permissions.openAccessibilitySettings()
                    }
                Text(text.enableCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(text.triggerLabel, selection: triggerBinding) {
                    ForEach(InstantInputSwitchTrigger.allCases) { trigger in
                        Text(text.triggerLabel(trigger)).tag(trigger)
                    }
                }
                Label(text.triggerNote(trigger), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if trigger == .fn {
                    fnUsageRow
                }
                if enabled, shadowedBySuperKey {
                    Label(text.superKeyConflict, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if enabled, service.isRunning {
                    Label(text.activeNow, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section(text.guardSection) {
                Toggle(text.guardToggle, isOn: $guardEnabled)
                    .onChange(of: guardEnabled) { _, _ in
                        InstantInputSwitchService.shared.syncWithPreferences()
                    }
                Text(text.guardCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(text.strategyLabel, selection: strategyBinding) {
                    ForEach(InputSourceGuardStrategy.allCases) { strategy in
                        Text(text.strategyLabel(strategy)).tag(strategy)
                    }
                }
                .disabled(!guardEnabled)
                Text(text.strategyCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: windowBinding,
                        in: InputSourceGuardSupport.millisecondsRange,
                        step: InputSourceGuardSupport.millisecondsStep) {
                    HStack {
                        Text(text.windowLabel)
                        Spacer()
                        Text(String(format: text.millisecondsFormat, windowBinding.wrappedValue))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!guardEnabled)
            }
            .disabled(!enabled)

            // A macOS setting of its own: it works with the feature off too.
            Section(text.indicatorSection) {
                Toggle(text.indicatorToggle, isOn: Binding(
                    get: { languageIndicatorShown },
                    set: { shown in
                        SystemLanguageIndicator.setEnabled(shown)
                        languageIndicatorShown = SystemLanguageIndicator.isEnabled
                    }))
                Text(text.indicatorCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if enabled, !permissions.accessibility {
                Section(l10n.s.permissionRequired) {
                    PermissionRow(kind: .accessibility)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            service.refreshFnUsage()
            languageIndicatorShown = SystemLanguageIndicator.isEnabled
        }
        // A change made in System Settings is read back on the way in.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            service.refreshFnUsage()
            languageIndicatorShown = SystemLanguageIndicator.isEnabled
        }
    }

    /// What macOS itself does on 🌐: fine when it does nothing, otherwise a
    /// warning with the way to the setting that fixes it.
    @ViewBuilder private var fnUsageRow: some View {
        let usage = service.fnUsage
        if usage == .doNothing {
            Label(text.fnUsageNote(usage), systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Label(text.fnUsageNote(usage),
                  systemImage: usage == .unknown ? "questionmark.circle" : "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(usage == .unknown ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
            Button(text.openKeyboardSettings) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private var triggerBinding: Binding<InstantInputSwitchTrigger> {
        Binding {
            trigger
        } set: { value in
            triggerRaw = value.rawValue
            InstantInputSwitchService.shared.syncWithPreferences()
        }
    }

    private var strategyBinding: Binding<InputSourceGuardStrategy> {
        Binding {
            InputSourceGuardStrategy.sanitized(strategyRaw)
        } set: { value in
            strategyRaw = value.rawValue
            InstantInputSwitchService.shared.syncWithPreferences()
        }
    }

    private var windowBinding: Binding<Int> {
        Binding {
            InputSourceGuardSupport.sanitizedMilliseconds(guardMilliseconds)
        } set: { value in
            guardMilliseconds = InputSourceGuardSupport.sanitizedMilliseconds(value)
            InstantInputSwitchService.shared.syncWithPreferences()
        }
    }
}
