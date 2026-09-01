cask "simpleclaudemenubar" do
  version "0.1.7"
  sha256 "13907c4841e6c74c2a205df8cada4b3f8927324770b839a1cc4da3ec89b759ce"

  url "https://github.com/baldwinsung/SimpleClaudeMenuBar/releases/download/v#{version}/SimpleClaudeMenuBar-#{version}.zip"
  name "SimpleClaudeMenuBar"
  desc "Menu bar app showing Claude Code session usage and reset time"
  homepage "https://github.com/baldwinsung/SimpleClaudeMenuBar"

  depends_on macos: :ventura

  app "SimpleClaudeMenuBar.app"

  caveats <<~EOS
    SimpleClaudeMenuBar is not notarized yet, so on first launch macOS may say
    it "cannot be opened because Apple cannot check it for malicious software."

    To open it, either:
      • Right-click the app in /Applications, choose Open, then confirm; or
      • Run:
          xattr -dr com.apple.quarantine "/Applications/SimpleClaudeMenuBar.app"

    It also requires the `claude` CLI on your PATH.
  EOS

  zap trash: [
    "~/Library/Preferences/com.baldwinsung.SimpleClaudeMenuBar.plist",
  ]
end
