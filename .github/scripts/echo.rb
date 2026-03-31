cask "echo" do
  version "1.0,1"
  sha256 :no_check # This will be updated with the actual SHA256 of the release zip

  url "https://github.com/tashda/Echo/releases/download/v#{version.before_comma}-#{version.after_comma}/Echo.zip"
  name "Echo"
  desc "Database management and SQL editor"
  homepage "https://github.com/tashda/Echo"

  # The --no-quarantine flag is recommended for users to bypass Gatekeeper
  # since the app is not notarized.
  # brew install --cask --no-quarantine tashda/tap/echo

  app "Echo.app"

  zap trash: [
    "~/Library/Application Support/Echo",
    "~/Library/Caches/dev.echodb.echo",
    "~/Library/Preferences/dev.echodb.echo.plist",
  ]
end
