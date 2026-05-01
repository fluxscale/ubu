cask "ubu" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/OWNER/ubu/releases/download/v#{version}/ubu.dmg"
  name "ubu"
  desc "Keeps your macOS Dock locked to your primary display"
  homepage "https://github.com/OWNER/ubu"

  depends_on macos: ">= :ventura"

  app "ubu.app"

  postflight do
    system "open", "#{appdir}/ubu.app"
  end

  zap trash: [
    "~/Library/Preferences/com.ubu.app.plist",
    "~/Library/Logs/com.ubu.app",
  ]
end
