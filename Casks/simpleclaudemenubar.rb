cask "simpleclaudemenubar" do
  version "0.1.2"
  sha256 "b6e5bae3e892d1fb7d7c176af79f6aebbd2a3f2e6ae3a7be07695631c53e6de3"

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
