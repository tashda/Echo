#!/bin/bash
#
# Echo Test Server Setup Script
# Run this on a fresh macOS Tahoe (Intel) server at 192.168.1.234
#
# Prerequisites: macOS Tahoe installed, SSH access, internet connection
# Apple ID NOT required (uses Xcode CLT + standalone Xcode)
#
set -euo pipefail

echo "=== Echo Test Server Setup ==="
echo "Target: macOS Tahoe (Intel) at $(hostname)"
echo ""

# ─── 1. Xcode Command Line Tools ───────────────────────────────────────────
echo ">>> Step 1: Xcode Command Line Tools"
if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "⚠️  A dialog will appear. Click 'Install', then re-run this script."
    exit 0
else
    echo "✅ Xcode CLT already installed at $(xcode-select -p)"
fi

# ─── 2. Homebrew ────────────────────────────────────────────────────────────
echo ""
echo ">>> Step 2: Homebrew"
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add to PATH for this session
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null || /opt/homebrew/bin/brew shellenv 2>/dev/null)"
else
    echo "✅ Homebrew already installed"
fi

# ─── 3. Core Dependencies ──────────────────────────────────────────────────
echo ""
echo ">>> Step 3: Core dependencies"
brew install git gh colima docker 2>/dev/null || true
echo "✅ Core dependencies installed"

# ─── 4. Colima (Docker Runtime) ────────────────────────────────────────────
echo ""
echo ">>> Step 4: Starting Colima (Docker runtime)"
if colima status &>/dev/null; then
    echo "✅ Colima already running"
else
    echo "Starting Colima with 4 CPUs, 8GB RAM, 60GB disk..."
    colima start --cpu 4 --memory 8 --disk 60
fi

# Verify Docker works
if docker info &>/dev/null; then
    echo "✅ Docker is functional"
else
    echo "❌ Docker not responding. Check Colima status."
    exit 1
fi

# ─── 5. Database Containers ────────────────────────────────────────────────
echo ""
echo ">>> Step 5: Database containers"

# PostgreSQL 16 (primary test target)
if docker ps --format '{{.Names}}' | grep -q echo-test-pg; then
    echo "✅ PostgreSQL container already running"
else
    echo "Starting PostgreSQL 16..."
    docker run -d --restart=always --name echo-test-pg \
        -e POSTGRES_PASSWORD=postgres \
        -e POSTGRES_DB=postgres \
        -p 54322:5432 \
        postgres:16
fi

# SQL Server 2022 (primary test target — Intel only)
if docker ps --format '{{.Names}}' | grep -q echo-test-mssql; then
    echo "✅ SQL Server container already running"
else
    echo "Starting SQL Server 2022..."
    docker run -d --restart=always --name echo-test-mssql \
        -e ACCEPT_EULA=Y \
        -e MSSQL_SA_PASSWORD='Password123!' \
        -e MSSQL_AGENT_ENABLED=true \
        -p 14332:1433 \
        mcr.microsoft.com/mssql/server:2022-latest
fi

# Wait for databases to be ready
echo "Waiting for databases to accept connections..."
for i in $(seq 1 60); do
    PG_READY=false
    MSSQL_READY=false

    if docker exec echo-test-pg pg_isready -U postgres &>/dev/null; then
        PG_READY=true
    fi

    if docker exec echo-test-mssql /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P 'Password123!' -C -Q "SELECT 1" &>/dev/null 2>&1 || \
       docker exec echo-test-mssql /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P 'Password123!' -Q "SELECT 1" &>/dev/null 2>&1; then
        MSSQL_READY=true
    fi

    if $PG_READY && $MSSQL_READY; then
        echo "✅ Both databases ready after ${i}s"
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "⚠️  Timeout waiting for databases. Check: docker logs echo-test-pg / echo-test-mssql"
    fi
    sleep 1
done

# ─── 6. Auto-start Colima on boot ──────────────────────────────────────────
echo ""
echo ">>> Step 6: Auto-start on boot"
PLIST_PATH="$HOME/Library/LaunchAgents/com.echo.colima.plist"
if [ ! -f "$PLIST_PATH" ]; then
    BREW_PREFIX=$(brew --prefix)
    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.echo.colima</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BREW_PREFIX}/bin/colima</string>
        <string>start</string>
        <string>--cpu</string>
        <string>4</string>
        <string>--memory</string>
        <string>8</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/colima.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/colima.err</string>
</dict>
</plist>
PLIST
    launchctl load "$PLIST_PATH"
    echo "✅ Colima auto-start configured"
else
    echo "✅ Colima auto-start already configured"
fi

# ─── 7. GitHub Actions Runner ──────────────────────────────────────────────
echo ""
echo ">>> Step 7: GitHub Actions self-hosted runner"
RUNNER_DIR="$HOME/actions-runner"
if [ -d "$RUNNER_DIR" ] && [ -f "$RUNNER_DIR/.runner" ]; then
    echo "✅ Runner already configured"
else
    echo ""
    echo "To set up the GitHub Actions runner:"
    echo ""
    echo "  1. Go to your Echo repo → Settings → Actions → Runners → New self-hosted runner"
    echo "  2. Select macOS, x64 architecture"
    echo "  3. Copy the token from the configure step"
    echo "  4. Run these commands:"
    echo ""
    echo "     mkdir -p ~/actions-runner && cd ~/actions-runner"
    echo "     curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-osx-x64-2.322.0.tar.gz"
    echo "     tar xzf actions-runner.tar.gz"
    echo "     ./config.sh --url https://github.com/YOUR_ORG/Echo --token YOUR_TOKEN --labels echo-test-server"
    echo "     ./svc.sh install"
    echo "     ./svc.sh start"
    echo ""
fi

# ─── 8. Verify everything ──────────────────────────────────────────────────
echo ""
echo "=== Verification ==="
echo "  Git:      $(git --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "  Brew:     $(brew --version 2>/dev/null | head -1 || echo 'NOT INSTALLED')"
echo "  Docker:   $(docker --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "  Colima:   $(colima version 2>/dev/null | head -1 || echo 'NOT INSTALLED')"
echo "  Xcode:    $(xcode-select -p 2>/dev/null || echo 'NOT INSTALLED')"
echo ""
echo "  Postgres: $(docker ps --format '{{.Status}}' --filter name=echo-test-pg 2>/dev/null || echo 'NOT RUNNING')"
echo "  MSSQL:    $(docker ps --format '{{.Status}}' --filter name=echo-test-mssql 2>/dev/null || echo 'NOT RUNNING')"
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Install Xcode 26 (required for building Echo)"
echo "  2. Set up the GitHub Actions runner (see step 7 above)"
echo "  3. Push the updated workflow to trigger a test run"
