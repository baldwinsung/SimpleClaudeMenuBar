# SimpleClaudeMenuBar

A tiny macOS menu bar app that shows your current **Claude Code session usage** and **when it resets**.

```
22% · 9:59p
```

Click it for the full breakdown:

- **Session** — % used and reset time
- **Week** — % used and reset time (all models)
- Last updated, refresh interval, manual refresh, quit

## How it works

Every few minutes the app runs:

```sh
claude -p "/usage"
```

…and parses the `Current session` / `Current week` lines. No API keys, no scraping — it just reads the same numbers `/usage` shows you. (Note: each refresh is itself a small `claude` invocation, so it adds slightly to your own request count. The interval is configurable — 1/5/15/30 min.)

## Install

```sh
brew install --cask baldwinsung/tap/simpleclaudemenubar
```

Then launch **SimpleClaudeMenuBar** from Spotlight or `/Applications`. It lives only in the menu bar (no Dock icon).

> Requires the [`claude`](https://docs.claude.com/en/docs/claude-code) CLI on your `PATH` and macOS 13 (Ventura) or later.

## Build from source

Requires Xcode 15+ / a recent Swift toolchain.

```sh
# Run the test suite
swift test

# Build an unsigned .app into ./build
scripts/build-app.sh 0.1.0
open build/SimpleClaudeMenuBar.app
```

## Releasing (maintainers)

Signed + notarized builds are produced with:

```sh
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="NOTARY_PROFILE"   # see scripts/release.sh for setup
scripts/release.sh 0.1.0
```

Then:

1. Create a GitHub release `v0.1.0` and upload `build/SimpleClaudeMenuBar-0.1.0.zip`.
2. Update `version` + `sha256` in `Casks/simpleclaudemenubar.rb` (sha printed by the script).
3. Copy that cask into the `baldwinsung/homebrew-tap` repo so `brew install --cask` resolves it.

## License

MIT — see [LICENSE](LICENSE).
