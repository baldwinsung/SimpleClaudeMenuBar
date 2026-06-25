# SimpleClaudeMenuBar

A tiny macOS menu bar app that shows your current **Claude Code session usage** and **when it resets**.

> Built with [Claude Code](https://claude.com/claude-code) (Opus).

```
✳ 35% used · 9:59p
```

Click it for the full breakdown — a Claude-style spark header, plus colored
gauges for each window:

- **Session** — % used, a progress bar, and reset time
- **Week** — % used, a progress bar, and reset time (all models)
- Last updated, refresh interval (1/5/15/30 min), manual refresh, quit

Gauge colors track how close you are to the limit: **green** under 70%,
**orange** 70–90%, **red** at 90%+.

## How it works

On launch and every few minutes, the app runs:

```sh
claude -p "/usage"
```

…and parses the `Current session` / `Current week` lines, e.g.:

```
Current session: 35% used · resets Jun 25 at 9:59pm (America/New_York)
Current week (all models): 73% used · resets Jun 28 at 1:59pm (America/New_York)
```

No API keys, no scraping — it just reads the same numbers `/usage` shows you.
The command runs through a login shell (`/bin/zsh -lc`) so your `PATH` (e.g.
Homebrew) is loaded even though a `.app` launches with a minimal environment.

> **Note:** each refresh is itself a small `claude` invocation, so it adds
> slightly to your own request count. The interval is configurable.

## Install

```sh
brew install --cask baldwinsung/tap/simpleclaudemenubar
```

Then launch **SimpleClaudeMenuBar** from Spotlight or `/Applications`. It lives
only in the menu bar (no Dock icon).

> Requires the [`claude`](https://docs.claude.com/en/docs/claude-code) CLI on
> your `PATH` and macOS 13 (Ventura) or later.

### Unsigned builds

Releases are currently **not notarized** (no Apple Developer ID yet), so on
first launch macOS may say the app "cannot be opened." Open it once via either:

- Right-click the app in `/Applications` ▸ **Open** ▸ confirm, or
- `xattr -dr com.apple.quarantine "/Applications/SimpleClaudeMenuBar.app"`

After that it launches normally. (Notarization will remove this step; see
`scripts/release.sh`.)

## Build from source

Requires Xcode 15+ / a recent Swift toolchain.

```sh
swift test                       # run the parser test suite
scripts/build-app.sh 0.1.0       # build an unsigned universal .app into ./build
open build/SimpleClaudeMenuBar.app
scripts/make-icon.sh             # (re)generate Resources/AppIcon.icns
```

## Project layout

```
Sources/SimpleClaudeMenuBar/
  App.swift          SwiftUI MenuBarExtra scene + dropdown UI (gauges)
  UsageModel.swift   ObservableObject: refresh timer, state, menu-bar title
  UsageFetcher.swift Runs `claude -p "/usage"` with a timeout
  UsageInfo.swift    Parses the /usage text into percent + reset time
  AppLogo.swift      The Claude-style "spark" mark + menu-bar image
Tests/                Parser unit tests
Resources/
  Info.plist         Bundle metadata (LSUIElement = menu-bar-only)
  AppIcon.icns       Generated app icon
scripts/
  build-app.sh       Build + assemble the universal .app
  release.sh         Sign (Developer ID) → notarize → staple → zip
  make-icon.sh       Render the app icon
Casks/               Homebrew cask (mirrored into baldwinsung/homebrew-tap)
```

## Releasing (maintainers)

GitHub Actions is **not** required — a release is a one-liner on your Mac
(your Developer ID and notary credentials live in your local keychain):

```sh
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="NOTARY_PROFILE"   # see scripts/release.sh for one-time setup
scripts/release.sh 0.1.0
```

Then:

1. Create a GitHub release `v0.1.0` and upload `build/SimpleClaudeMenuBar-0.1.0.zip`.
2. Update `version` + `sha256` in the cask (the sha is printed by the script).
3. Mirror that cask into the public **`baldwinsung/homebrew-tap`** repo so
   `brew install --cask` resolves it.

## Credits

Designed and built by **[Claude Code](https://claude.com/claude-code) (Opus)**.

The "spark" logo is an original drawing approximating Claude's mark — it is
**not** Anthropic's official trademarked logo. Swap in the real asset
(`scripts/make-icon.sh` for the icon, `ClaudeSpark` in `AppLogo.swift` for the
in-app vector) if you have it.

## License

MIT — see [LICENSE](LICENSE).
