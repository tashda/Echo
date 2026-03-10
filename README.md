# <img src=".github/assets/app_icon.png" width="64" align="left" style="margin-right: 15px;"> Echo

<br>

A native macOS database client for PostgreSQL, MySQL, SQLite, and Microsoft SQL Server.

## Installation

### Via Homebrew (Recommended)
To install Echo using Homebrew and bypass macOS Gatekeeper (as it's currently ad-hoc signed), run:

```bash
brew install --cask --no-quarantine tashda/tap/echo
```

### Manual Download
You can also download the latest `.zip` from the [Releases](https://github.com/tashda/Echo/releases) page. 

*Note: If you install manually, you may need to Right-Click the app and select **Open** the first time to bypass the "unverified developer" warning.*

## Auto-Updates
Echo uses the [Sparkle](https://sparkle-project.org) framework for secure automatic updates using EdDSA (Ed25519) signatures. You can manually check for updates via **Echo > Check for Updates...** or wait for the app to notify you when a new version is released.

## CI/CD & Automated Releases
This repository is configured with a GitHub Actions pipeline (`.github/workflows/build-release.yml`) that automates the entire distribution process.

- **Trigger:** Any push or pull-request merge to the `main` branch.
- **Process:** The workflow builds the app using Xcode 16 (macOS 15), packages it as a ZIP, signs the update with Sparkle keys, and publishes a new GitHub Release.
- **Appcast:** The Sparkle update feed (`appcast.xml`) is automatically updated and hosted within each release.

### Developer Setup
To maintain the automated pipeline:
1. Ensure the **Sparkle** Swift Package is added to the Xcode project.
2. Store the Sparkle private key in GitHub Secrets as `SPARKLE_PRIVATE_KEY`.
3. The Homebrew Cask formula is located in `scripts/echo.rb` and should be synced with your `homebrew-tap` repository as needed.
