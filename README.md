<div align="center">
  <img src=".github/assets/app_icon.png" width="128" height="128" alt="Echo App Icon">
  <h1>Echo</h1>
  <p><strong>The Definitive Database Client for macOS 26 Tahoe</strong></p>

  [![Website](https://img.shields.io/badge/website-echodb.dev-blue?style=for-the-badge)](https://echodb.dev)
  [![macOS](https://img.shields.io/badge/macOS-26%2B-black?style=for-the-badge&logo=apple)](https://developer.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.2-orange?style=for-the-badge&logo=swift)](https://swift.org)

  <p>
    <a href="#-key-features">Features</a> •
    <a href="#-the-engine-custom-built-native-drivers">Engine</a> •
    <a href="#-supported-databases">Databases</a> •
    <a href="#-installation">Installation</a>
  </p>
</div>

---

**Echo** is a high-performance, strictly native database management suite built exclusively for the modern macOS era. Eschewing the resource-heavy paradigms of Electron and Java, Echo leverages **Swift 6.2** and the **macOS 26 Tahoe** design language to deliver a tool that feels like a first-class citizen on your Mac.

Designed for engineers who demand precision, Echo combines a minimalist aesthetic with deep, dialect-specific functionality for PostgreSQL, Microsoft SQL Server, and more.

---

## ✨ Key Features

### 🧠 EchoSense™ Intelligence
Stop fighting with syntax. EchoSense is our context-aware SQL autocomplete engine that understands your schema, foreign keys, and dialect-specific quirks. It doesn't just suggest keywords; it predicts your intent.
- **Dialect-Aware:** Precise suggestions for T-SQL, PL/pgSQL, and SQLite.
- **Schema Navigation:** Autocomplete tables, columns, and joins based on live metadata.

### ⚙️ Activity Engine
Long-running operations shouldn't be a black box. Our centralized **Activity Engine** tracks backups, restores, and maintenance tasks directly in the native toolbar.
- **Real-time Progress:** Visual feedback for every background task.
- **Detailed History:** Audit exactly what happened and when.

### 🛠️ Professional Maintenance Suite
Go beyond simple queries. Echo provides deep integration for database administration:
- **MSSQL Power Tools:** Rebuild indexes, check integrity, and manage agent jobs with native UI.
- **Postgres Management:** Vacuum, reindex, and security label management.
- **Schema Browser:** A lightning-fast, hierarchical view of your entire database structure.

### 📊 Streaming Query Workspace
Experience zero-lag result sets. Echo streams data directly from the wire to a hardware-accelerated grid.
- **Execution Plans:** Visualize how your queries run to find bottlenecks.
- **Native Rendering:** Handles millions of rows with minimal memory footprint.

---

## 🏗️ The Engine: Custom-Built Native Drivers

Unlike other database clients that rely on generic, multi-platform libraries, Echo is powered by a suite of **first-party, custom-built database drivers**. We maintain the entire stack to ensure absolute performance, memory efficiency, and seamless integration with Swift's modern concurrency model.

- **[postgres-wire](https://github.com/tashda/postgres-wire):** A high-performance, pure Swift implementation of the PostgreSQL wire protocol. No C-dependencies, just raw speed.
- **[sqlserver-nio](https://github.com/tashda/sqlserver-nio):** Built on SwiftNIO, this driver provides an asynchronous, non-blocking bridge to Microsoft SQL Server, supporting advanced T-SQL features.
- **[mysql-wire](https://github.com/tashda/mysql-wire):** Our native MySQL implementation, currently in active development to bring the same performance standards to the MySQL ecosystem.

### What this means for you:
- **Zero Overhead:** No translation layers between the UI and the database socket.
- **Data-Race Safety:** Built from the ground up for **Swift 6.2**, ensuring compile-time safety for your data.
- **Native Efficiency:** Minimal memory footprint even when streaming millions of rows.

---

## 🗄️ Supported Databases

| Database | Status | Features |
| :--- | :--- | :--- |
| **PostgreSQL** | 🟢 Stable | Streaming, Metadata, Security, Maintenance |
| **Microsoft SQL Server** | 🟢 Stable | T-SQL, Agent Jobs, Maintenance, Indexing |
| **SQLite** | 🟢 Stable | Local browser, Full Schema Support |
| **MySQL** | 🟡 Beta | Query Execution, Table Exploration |

---

## 🚀 Installation

Echo is distributed as a standalone, signed macOS application. 

1. **Download:** Grab the latest release from the [GitHub Releases](https://github.com/tashda/Echo/releases) page or visit [echodb.dev](https://echodb.dev).
2. **Move to Applications:** Drag `Echo.app` into your `/Applications` folder.
3. **Auto-Updates:** Echo includes a built-in update mechanism powered by **Sparkle**. You will be notified automatically when a new version is available.

---

## 🛠️ Developer Setup

```bash
# Clone the repository
git clone https://github.com/tashda/Echo.git

# Open in Xcode 26+
open Echo.xcodeproj

# Build and Run
# Ensure the 'Echo' scheme is selected (Cmd + R)
```

---

<div align="center">
  <p>Built with ❤️ by the Echo Team.</p>
  <p><a href="https://echodb.dev">echodb.dev</a></p>
</div>
