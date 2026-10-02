<div align="center">
  <img src=".github/assets/echo-mark.svg" width="120" alt="Echo">
  <h1>Echo</h1>
  <p>A database client for macOS.</p>
</div>

Echo is a native macOS app for working with databases. It is written in Swift with SwiftUI and AppKit, and requires macOS 26 or later.

It connects to PostgreSQL, MySQL, Microsoft SQL Server and SQLite. You can browse a database's objects in a sidebar tree, write and run SQL in query tabs, view results in a grid, and use the administration tools for each database type, such as maintenance, security and server activity. EchoSense provides SQL autocomplete based on the connected database's schema.

SQL Server connections use our own Swift package, [echo-sqlserver](https://github.com/tashda/echo-sqlserver). [EchoSense](https://github.com/tashda/echo-sense) provides the SQL autocomplete.

## Download

Releases are on the [Releases](https://github.com/tashda/Echo/releases) page. The latest build of the `dev` branch is published there every night as the pre-release **Echo Nightly**. Release builds update themselves through Sparkle; the nightly does not.

More information is at [echodb.dev](https://echodb.dev).

## Building

You need Xcode 26 or later.

```bash
git clone https://github.com/tashda/Echo.git
cd Echo
cp Echo/Configuration/Secrets.xcconfig.example Echo/Configuration/Secrets.xcconfig
open Echo.xcodeproj
```

Select the `Echo` scheme and run. `Secrets.xcconfig` holds the cloud sync settings; the example values are placeholders, so sync does not work without your own.

## Design

Echo's design language and decisions are in [`Design/`](Design/README.md).
