// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

// Shows, on this Mac, whether a process reads its own input source switch back
// at once. TIS learns of a selection through a notice its run loop delivers;
// until then it keeps reporting what it reported before. Instant input switch
// and the Super key count each press from that report, and see through an old
// one (InputSourceGuardSupport.effectiveCurrentID); this measures how often
// and how long the report lags when the run loop turns between switches, as
// an app's main thread does between key presses.
//
// It switches the input source back and forth a number of times within about
// a second, then restores the source that was selected before. Needs no
// permission. Do not type while it runs. Run from Terminal, TIS also logs
// "TSMSendMessageToUIServer ... FAILED": a command-line tool has no input
// UI to talk to, which does not affect what is measured.
//
//   swift Tools/CheckInputSourceSwitch.swift [rounds]

import Carbon.HIToolbox
import Foundation

func string(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
}

func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
}

func currentID() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
    return string(source, kTISPropertyInputSourceID)
}

let rounds = max(1, CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 20)
let sources = ((TISCreateInputSourceList(nil, false)?.takeRetainedValue() as NSArray?) as? [TISInputSource] ?? [])
    .filter {
        string($0, kTISPropertyInputSourceCategory) == kTISCategoryKeyboardInputSource as String
            && flag($0, kTISPropertyInputSourceIsSelectCapable)
    }
guard sources.count > 1 else {
    print("Only one input source is enabled; there is nothing to switch between.")
    exit(1)
}
guard let originalID = currentID(),
      let original = sources.first(where: { string($0, kTISPropertyInputSourceID) == originalID }),
      let other = sources.first(where: { string($0, kTISPropertyInputSourceID) != originalID }),
      let otherID = string(other, kTISPropertyInputSourceID)
else {
    print("Could not read the current input source.")
    exit(1)
}

// Ctrl-C puts the original source back before leaving. The signal is taken
// on the main queue, which the run loop below drains between switches.
signal(SIGINT, SIG_IGN)
let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
interrupt.setEventHandler {
    TISSelectInputSource(original)
    print("\nInterrupted; selected \(originalID) again.")
    exit(130)
}
interrupt.resume()

print("Switching \(originalID) ⇄ \(otherID), \(rounds) rounds…")
var immediate = 0
var stale: [String] = []
var refused: [String] = []
var worstMicroseconds = 0.0
var worstCatchUpMilliseconds = 0.0

/// Waits up to half a second for TIS to report `id`; the milliseconds it took.
/// TIS learns of a selection through notifications its run loop delivers, so
/// the wait turns the run loop the way an app's main thread would.
func catchUp(to id: String, since start: Date) -> Double? {
    while Date().timeIntervalSince(start) < 0.5 {
        if currentID() == id { return Date().timeIntervalSince(start) * 1000 }
        RunLoop.current.run(until: Date().addingTimeInterval(0.0005))
    }
    return nil
}
for round in 1...rounds {
    for (target, targetID) in [(other, otherID), (original, originalID)] {
        let started = Date()
        guard TISSelectInputSource(target) == noErr else {
            refused.append("round \(round): selecting \(targetID) was refused")
            continue
        }
        let read = currentID()
        // Between presses an app's main thread turns its run loop; so does this.
        defer { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        worstMicroseconds = max(worstMicroseconds, Date().timeIntervalSince(started) * 1_000_000)
        if read == targetID {
            immediate += 1
        } else {
            let caughtUp = catchUp(to: targetID, since: started)
            worstCatchUpMilliseconds = max(worstCatchUpMilliseconds, caughtUp ?? 500)
            stale.append("round \(round): selected \(targetID), read \(read ?? "nothing")"
                         + (caughtUp.map { String(format: ", caught up after %.1f ms", $0) } ?? ", never caught up"))
        }
    }
}
TISSelectInputSource(original)
let restored = catchUp(to: originalID, since: Date()) != nil

let total = rounds * 2
print("Read back at once: \(immediate) of \(total) switches (slowest select + read: \(Int(worstMicroseconds)) µs).")
if !refused.isEmpty {
    print("REFUSED by TIS in \(refused.count) switches:")
    refused.prefix(10).forEach { print("  \($0)") }
}
if stale.isEmpty {
    print("OK: with the run loop turning between switches, the report was current every time.")
} else {
    print("STALE reads in \(stale.count) switches (slowest catch-up: \(Int(worstCatchUpMilliseconds)) ms).")
    print("UnTangle counts a press from the source it last selected while the report is still the old one.")
    stale.prefix(10).forEach { print("  \($0)") }
}
print(restored ? "Restored \(originalID)." : "Could not confirm \(originalID) was restored: check the Input menu.")
exit(stale.isEmpty && refused.isEmpty ? 0 : 2)
