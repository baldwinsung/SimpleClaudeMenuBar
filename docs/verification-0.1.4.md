# 0.1.4 — refresh-interval crash on macOS 26: analysis & verification

**Status:** Fixed in 0.1.4 · Verified on macOS 26.5.2 (build 25F84), Apple silicon.

## Symptom

On macOS 26, the app crashed (`EXC_BAD_ACCESS` / `SIGSEGV`) when the user changed
the **"Refresh every"** interval in the menu. Two on-device crash reports
(`~/Library/Logs/DiagnosticReports/SimpleClaudeMenuBar-2026-06-25-*.ips`,
macOS 26.5.1, app 0.1.1) were identical, both terminating with:

```
EXC_BAD_ACCESS (SIGSEGV) — "Thread stack size exceeded due to excessive recursion"
  UsageModel.refreshMinutes.setter → .didset → .setter → .didset → …   (×100+)
  ← Combine Published.subscript.setter
  ← SwiftUICore ObjectLocation.set(_:transaction:)   (Picker binding writeback)
```

## Root cause

`UsageModel.refreshMinutes` re-assigned itself inside its own `didSet` to clamp
the range:

```swift
@Published var refreshMinutes: Int {
    didSet {
        refreshMinutes = max(1, min(refreshMinutes, 120))   // self-assign
        ...
    }
}
```

Swift's rule that "assigning a property inside its own `didSet` does **not**
re-trigger the observer" applies to *stored* properties. For an `@Published`
property the observer lives on the **property wrapper's computed accessor**, so
the self-assignment re-enters the setter and recurses until the stack overflows.

The trigger in the running app is SwiftUI writing back through the Picker's
`$model.refreshMinutes` binding — every selection change calls the setter,
recursing infinitely. It fires even when the value is already in range (the
clamp is a no-op but still re-assigns), so it was a guaranteed crash on any
interval change.

## Fix

Only re-assign when the value is actually out of range, so the clamp bottoms out
after at most one hop instead of recursing:

```swift
@Published var refreshMinutes: Int {
    didSet {
        let clamped = max(1, min(refreshMinutes, 120))
        if clamped != refreshMinutes {
            refreshMinutes = clamped
            return
        }
        UserDefaults.standard.set(refreshMinutes, forKey: Self.intervalKey)
        scheduleTimer()
    }
}
```

Regression test: `UsageParserTests.testRefreshMinutesClampsWithoutRecursing`
(a recurrence would crash the test process rather than fail an assertion).

## Verification (runtime, on macOS 26.5.2)

Reproduced the exact pre-fix crash path — SwiftUI writing back through the
Picker binding into `refreshMinutes.didSet` — against the **shipped 0.1.4 app**
installed via Homebrew.

**Baseline (21:36:08):** pid `7758`, started 21:30:49; `refreshMinutes` UserDefault
*unset*; 2 crash reports on disk (both Jun 25).

**Action:** changed the "Refresh every" Picker several times in the running app.

**Result (21:37:17):**

| Signal | Baseline | After driving the Picker |
| --- | --- | --- |
| Process | pid 7758 | pid **7758** — same process, never restarted |
| `refreshMinutes` UserDefault | unset | **`10`** — a concrete written value |
| Crash reports on disk | 2 | **2** — no new `.ips` |
| Unified-log faults (last 10m) | — | none |

The persisted UserDefault flipping from *unset* to a concrete value is positive
proof the `didSet` body executed to completion (it calls
`UserDefaults.standard.set`) — the recursion path ran and returned normally
instead of overflowing the stack.

Pre-fix, the same action segfaults immediately. Confirmed independently with a
minimal reproduction: `@Published var v: Int { didSet { v = max(1, min(v,120)) } }`
crashes with exit 139 (SIGSEGV) even on an in-range assignment; the guarded
version exits 0.

**Verdict: PASS.**
