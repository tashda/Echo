# Echo Project Overview

The project "Echo" is a macOS application developed using Swift and SwiftUI. It functions as a database client, providing tools for connecting to, querying, and managing various types of databases including PostgreSQL, MySQL, SQLite, and Microsoft SQL Server. The application leverages NIO (NIO.framework) for database interactions and includes a local Swift package, `EchoSense`, which handles database schema metadata. It also integrates `sqruff`, a Rust-based SQL formatting tool, to maintain code quality.

## Key Features:
*   **Multi-database support:** Connects to PostgreSQL, MySQL, SQLite, and Microsoft SQL Server.
*   **Query Editor:** Provides a tabbed interface for writing and executing SQL queries.
*   **Schema Browsing:** Displays database, schema, table, view, materialized view, function, trigger, and column information.
*   **Autocomplete:** Assists users in writing SQL queries.
*   **Connection Management:** Allows users to manage multiple database connections and projects.
*   **Performance Monitoring:** Includes a tool for monitoring query performance.
*   **SQL Formatting:** Integrates `sqruff` for SQL code formatting.
*   **Theming:** Supports custom themes and appearance settings.

## Architecture:
The application follows a Model-View-ViewModel (MVVM) like architecture, with `AppCoordinator` acting as a central manager for application state and dependencies. `AppModel` and `AppState` manage the core data and UI state, respectively. `EchoSense` provides the domain models for database schema.

## Building and Running:
This is an Xcode project. To build and run the application, open `Echo.xcodeproj` in Xcode.

1.  **Open Project:** `open Echo.xcodeproj`
2.  **Select Target:** Choose the "Echo" target.
3.  **Build and Run:** Use Xcode's standard build and run commands (Cmd+R).

The `build_sqruff.sh` script handles the `sqruff` binary, either by downloading a pre-built version or compiling it from source. This script is executed as part of the Xcode build process.

## Development Conventions:
*   **SwiftUI:** The UI is built using SwiftUI.
*   **Swift Concurrency:** Uses `async/await` for asynchronous operations. All code must adhere to Swift 6 data-race safety checks and concurrency rules.
*   **Combine:** Utilizes the Combine framework for reactive programming.
*   **SQL Formatting:** Adheres to `sqruff` formatting rules for SQL code.
*   **Database Interaction:** Uses NIO-based libraries for database connectivity.
