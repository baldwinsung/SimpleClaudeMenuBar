cask "simpleclaudemenubar" do
  version "0.1.5"
  sha256 "e355fd9c772cce4b672d72cc609b20efccf2e6b941f342b6797de5d55fd80cbd"

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
