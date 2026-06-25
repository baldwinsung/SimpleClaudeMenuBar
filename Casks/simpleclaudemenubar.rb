cask "simpleclaudemenubar" do
  version "0.1.0"
  sha256 "REPLACE_WITH_ZIP_SHA256"

  url "https://github.com/baldwinsung/SimpleClaudeMenuBar/releases/download/v#{version}/SimpleClaudeMenuBar-#{version}.zip"
  name "SimpleClaudeMenuBar"
  desc "Menu bar app showing Claude Code session usage and reset time"
  homepage "https://github.com/baldwinsung/SimpleClaudeMenuBar"

  depends_on macos: ">= :ventura"

  app "SimpleClaudeMenuBar.app"

  zap trash: [
    "~/Library/Preferences/com.baldwinsung.SimpleClaudeMenuBar.plist",
  ]
end
