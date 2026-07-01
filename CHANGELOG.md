# Changelog

All notable changes to SimpleClaudeMenuBar are documented here.

## 0.1.4

- Fix a **crash when changing the refresh interval** on macOS 26. The
  `refreshMinutes` clamp re-assigned the property from inside its own `didSet`,
  which re-enters the `@Published` setter and recurses until the stack
  overflows (`EXC_BAD_ACCESS`). The clamp now only re-assigns when the value is
  actually out of range. Recommended for anyone on macOS 26.

## 0.1.3

- Fix intermittent **"Couldn't parse /usage output"** errors. `claude -p /usage`
  occasionally omits the `Current session` / `Current week` limit lines (a
  server-side fetch that sometimes returns nothing) while still printing the
  rest of the breakdown. The app now retries once on a miss and keeps showing
  the last good snapshot instead of replacing it with an error.

## 0.1.2

- Add a **Launch at login** checkbox, backed by `SMAppService.mainApp`
  (macOS 13+). Toggling registers/unregisters the app as a per-user login item.
- Default refresh interval is now 10 minutes.
- README badges.

## 0.1.1

- Avoid the macOS Documents privacy prompt by invoking `claude` directly
  (not via a login shell) from a neutral temp directory.
- Fix on-the-hour reset time formatting.

## 0.1.0

- Initial release: menu-bar app showing Claude Code session/week usage and
  reset times, with colored gauges and a configurable refresh interval.
