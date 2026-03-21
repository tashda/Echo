#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE_SQLSERVER_REPO="$ROOT_DIR/vendor/sqlserver-nio"
WORKSPACE_POSTGRES_REPO="$ROOT_DIR/vendor/postgres-wire"
SIBLING_SQLSERVER_REPO="$(cd "$ROOT_DIR/.." && pwd)/sqlserver-nio"
SIBLING_POSTGRES_REPO="$(cd "$ROOT_DIR/.." && pwd)/postgres-wire"
FIXTURE_DIR="$ROOT_DIR/.ci-fixtures"
FIXTURE_ENV_FILE="$FIXTURE_DIR/test-fixtures.env"

if [[ -z "${SQLSERVER_REPO:-}" ]]; then
  if [[ -d "$WORKSPACE_SQLSERVER_REPO" ]]; then
    SQLSERVER_REPO="$WORKSPACE_SQLSERVER_REPO"
  else
    SQLSERVER_REPO="$SIBLING_SQLSERVER_REPO"
  fi
fi

if [[ -z "${POSTGRES_REPO:-}" ]]; then
  if [[ -d "$WORKSPACE_POSTGRES_REPO" ]]; then
    POSTGRES_REPO="$WORKSPACE_POSTGRES_REPO"
  else
    POSTGRES_REPO="$SIBLING_POSTGRES_REPO"
  fi
fi

mkdir -p "$FIXTURE_DIR"
: > "$FIXTURE_ENV_FILE"

# ── Shared helpers ───────────────────────────────────────────────────────────

write_summary() {
  local name="$1"
  local output="$2"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "### ${name} fixture"
      echo ""
      echo '```'
      echo "$output"
      echo '```'
      echo ""
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

append_env() {
  local key="$1"
  local value="$2"
  export "${key}=${value}"
  export "TEST_RUNNER_${key}=${value}"
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "${key}=${value}" >> "$GITHUB_ENV"
    echo "TEST_RUNNER_${key}=${value}" >> "$GITHUB_ENV"
  fi
  mkdir -p "$FIXTURE_DIR"
  if [[ -f "$FIXTURE_ENV_FILE" ]]; then
    python3 - "$FIXTURE_ENV_FILE" "$key" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
lines = []
for raw in path.read_text().splitlines():
    if not raw.startswith(f"{key}="):
        lines.append(raw)
path.write_text("\n".join(lines) + ("\n" if lines else ""))
PY
  fi
  echo "${key}=${value}" >> "$FIXTURE_ENV_FILE"
}

detect_sqlcmd() {
  local container="$1"
  if docker exec "$container" test -x /opt/mssql-tools18/bin/sqlcmd 2>/dev/null; then
    echo "/opt/mssql-tools18/bin/sqlcmd"
  elif docker exec "$container" test -x /opt/mssql-tools/bin/sqlcmd 2>/dev/null; then
    echo "/opt/mssql-tools/bin/sqlcmd"
  else
    echo "/opt/mssql-tools18/bin/sqlcmd"  # fallback
  fi
}

wait_for_sqlserver() {
  local container="$1"
  local password="$2"
  local max_wait="${3:-60}"
  echo "⏳ Waiting for SQL Server in $container..."
  for i in $(seq 1 "$max_wait"); do
    # Try both sqlcmd paths (2017 uses mssql-tools, 2019+ uses mssql-tools18)
    if docker exec "$container" /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U sa -P "$password" -C -Q "SELECT 1" > /dev/null 2>&1; then
      echo "✅ SQL Server ready after ${i}s"
      return 0
    elif docker exec "$container" /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P "$password" -Q "SELECT 1" > /dev/null 2>&1; then
      echo "✅ SQL Server ready after ${i}s"
      return 0
    fi
    sleep 1
  done
  echo "❌ SQL Server not ready after ${max_wait}s"
  return 1
}

# ── SQL Server fixture ───────────────────────────────────────────────────────

ensure_sqlserver() {
  local version="${ECHO_MSSQL_VERSION:-2022-latest}"
  local compat="${ECHO_MSSQL_COMPAT:-}"
  local password="Password123!"
  local port="${ECHO_MSSQL_PORT:-14332}"
  local container_name="echo-test-mssql-${version//\//-}"
  local image="mcr.microsoft.com/mssql/server:${version}"

  # For compat-level emulation, older versions use the 2017 image
  if [[ -n "$compat" ]]; then
    container_name="echo-test-mssql-compat-${compat}"
  fi

  echo "🔧 SQL Server fixture: version=$version compat=${compat:-none} port=$port container=$container_name"

  # Check if container already exists and is running with correct image
  local existing_id
  existing_id=$(docker ps -q --filter "name=^${container_name}$" 2>/dev/null || true)

  if [[ -n "$existing_id" ]]; then
    echo "♻️  Reusing existing container $container_name"
  else
    # Remove stopped container if exists
    docker rm -f "$container_name" 2>/dev/null || true

    # Find a free port if the default is in use
    if docker ps --format '{{.Ports}}' | grep -q ":${port}->"; then
      port=$((port + 100))
      echo "⚠️  Port conflict, using $port instead"
    fi

    echo "🚀 Starting SQL Server $version on port $port..."
    docker run -d \
      --name "$container_name" \
      --platform linux/amd64 \
      -e "ACCEPT_EULA=Y" \
      -e "MSSQL_SA_PASSWORD=$password" \
      -e "MSSQL_AGENT_ENABLED=true" \
      -p "${port}:1433" \
      --restart unless-stopped \
      "$image"

    wait_for_sqlserver "$container_name" "$password" 60
  fi

  # Detect sqlcmd path for this container and build a helper function
  local sqlcmd_path
  sqlcmd_path=$(detect_sqlcmd "$container_name")

  # Helper: run sqlcmd in the container with proper arguments
  run_sqlcmd() {
    if [[ "$sqlcmd_path" == *"tools18"* ]]; then
      docker exec "$container_name" "$sqlcmd_path" -S localhost -U sa -P "$password" -C "$@"
    else
      docker exec "$container_name" "$sqlcmd_path" -S localhost -U sa -P "$password" "$@"
    fi
  }

  # Apply compat level if specified
  if [[ -n "$compat" ]]; then
    echo "⚙️  Setting compatibility level to $compat..."
    run_sqlcmd -Q "ALTER DATABASE [master] SET COMPATIBILITY_LEVEL = $compat;" \
      2>/dev/null || echo "⚠️  Failed to set compat level (may not be supported)"
  fi

  # Load AdventureWorks if not present
  local has_aw
  has_aw=$(run_sqlcmd -h -1 \
    -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = 'AdventureWorks'" \
    2>/dev/null | tr -d '[:space:]' || echo "0")

  if [[ "$has_aw" != "1" ]]; then
    echo "📦 Loading AdventureWorks..."
    # Download AdventureWorks backup if not cached
    local bak_dir="$FIXTURE_DIR/adventureworks"
    local bak_file="$bak_dir/AdventureWorks-${version}.bak"
    mkdir -p "$bak_dir"

    if [[ ! -f "$bak_file" ]]; then
      echo "⬇️  Downloading AdventureWorks backup..."
      # Use version-appropriate backup — 2017 needs AdventureWorks2017, 2019+ can use 2022
      local bak_url
      case "$version" in
        2017*) bak_url="https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2017.bak" ;;
        2019*) bak_url="https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak" ;;
        *)     bak_url="https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2022.bak" ;;
      esac
      curl -sSL -o "$bak_file" "$bak_url"
    fi

    # Copy backup into container
    docker exec "$container_name" mkdir -p /var/opt/mssql/backup 2>/dev/null || true
    docker cp "$bak_file" "${container_name}:/var/opt/mssql/backup/AdventureWorks.bak"

    # Detect logical file names from the backup
    local data_logical log_logical
    data_logical=$(run_sqlcmd -h -1 -W \
      -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backup/AdventureWorks.bak'" \
      2>/dev/null | head -1 | awk '{print $1}' || echo "AdventureWorks")
    log_logical=$(run_sqlcmd -h -1 -W \
      -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backup/AdventureWorks.bak'" \
      2>/dev/null | sed -n '2p' | awk '{print $1}' || echo "AdventureWorks_log")
    echo "📁 Logical names: data=$data_logical log=$log_logical"

    # Restore with detected logical names
    run_sqlcmd \
      -Q "RESTORE DATABASE [AdventureWorks] FROM DISK = N'/var/opt/mssql/backup/AdventureWorks.bak' WITH MOVE N'${data_logical}' TO N'/var/opt/mssql/data/AdventureWorks.mdf', MOVE N'${log_logical}' TO N'/var/opt/mssql/data/AdventureWorks_log.ldf', REPLACE, STATS = 25;" \
      2>&1 || echo "⚠️  AdventureWorks restore failed (may already exist or backup incompatible)"

    # Apply compat level to AdventureWorks too
    if [[ -n "$compat" ]]; then
      run_sqlcmd -Q "ALTER DATABASE [AdventureWorks] SET COMPATIBILITY_LEVEL = $compat;" \
        2>/dev/null || true
    fi
  else
    echo "✅ AdventureWorks already present"
  fi

  # Resolve actual port from running container
  local actual_port
  actual_port=$(docker port "$container_name" 1433 2>/dev/null | head -1 | sed 's/.*://' || echo "$port")

  local summary="fixture=sqlserver
version=$version
compat=${compat:-none}
port=$actual_port
container=$container_name
adventureworks=true"
  echo "$summary"
  write_summary "SQL Server ($version, compat=${compat:-native})" "$summary"

  append_env "USE_DOCKER" "1"
  append_env "ECHO_USE_PACKAGE_FIXTURES" "1"
  append_env "ECHO_MSSQL_FIXTURE_VALIDATED" "1"
  append_env "ECHO_MSSQL_PORT" "$actual_port"
}

# ── PostgreSQL fixture ───────────────────────────────────────────────────────

ensure_postgres() {
  local pg_version="${ECHO_PG_VERSION:-17}"
  local port="${ECHO_PG_PORT:-54322}"
  local container_name="echo-test-pg-${pg_version}"
  local image="postgres:${pg_version}"
  local password="postgres"

  echo "🔧 Postgres fixture: version=$pg_version port=$port container=$container_name"

  local existing_id
  existing_id=$(docker ps -q --filter "name=^${container_name}$" 2>/dev/null || true)

  if [[ -n "$existing_id" ]]; then
    echo "♻️  Reusing existing container $container_name"
  else
    docker rm -f "$container_name" 2>/dev/null || true

    if docker ps --format '{{.Ports}}' | grep -q ":${port}->"; then
      port=$((port + 100))
      echo "⚠️  Port conflict, using $port instead"
    fi

    echo "🚀 Starting Postgres $pg_version on port $port..."
    docker run -d \
      --name "$container_name" \
      -e "POSTGRES_PASSWORD=$password" \
      -p "${port}:5432" \
      --restart unless-stopped \
      "$image"

    echo "⏳ Waiting for Postgres..."
    for i in $(seq 1 30); do
      if docker exec "$container_name" pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ Postgres ready after ${i}s"
        break
      fi
      sleep 1
    done
  fi

  local actual_port
  actual_port=$(docker port "$container_name" 5432 2>/dev/null | head -1 | sed 's/.*://' || echo "$port")

  local summary="fixture=postgres
version=$pg_version
port=$actual_port
container=$container_name"
  echo "$summary"
  write_summary "Postgres $pg_version" "$summary"

  append_env "USE_DOCKER" "1"
  append_env "ECHO_USE_PACKAGE_FIXTURES" "1"
  append_env "ECHO_PG_FIXTURE_VALIDATED" "1"
  append_env "ECHO_PG_HOST" "127.0.0.1"
  append_env "ECHO_PG_PORT" "$actual_port"
  append_env "ECHO_PG_DATABASE" "postgres"
  append_env "ECHO_PG_USER" "postgres"
  append_env "ECHO_PG_PASSWORD" "postgres"
  append_env "TEST_PG_HOST" "127.0.0.1"
  append_env "TEST_PG_PORT" "$actual_port"
  append_env "TEST_PG_DATABASE" "postgres"
  append_env "TEST_PG_USER" "postgres"
  append_env "TEST_PG_PASSWORD" "postgres"

  prepare_postgres_backup_database "$actual_port"
}

prepare_postgres_backup_database() {
  local port="$1"
  local database="echo_backup_restore_test"
  local psql_path=""

  if [[ -n "${TEST_PG_TOOL_PATH:-}" && -x "${TEST_PG_TOOL_PATH}/psql" ]]; then
    psql_path="${TEST_PG_TOOL_PATH}/psql"
  elif [[ -n "${ECHO_PG_TOOL_PATH:-}" && -x "${ECHO_PG_TOOL_PATH}/psql" ]]; then
    psql_path="${ECHO_PG_TOOL_PATH}/psql"
  else
    psql_path="$(command -v psql)"
  fi

  PGPASSWORD=postgres PGSSLMODE=disable "$psql_path" \
    --host 127.0.0.1 \
    --port "$port" \
    --username postgres \
    --dbname postgres \
    --no-password \
    -v ON_ERROR_STOP=1 <<SQL
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$database' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS "$database";
CREATE DATABASE "$database";
SQL

  append_env "ECHO_PG_BACKUP_DATABASE" "$database"
  append_env "TEST_PG_BACKUP_DATABASE" "$database"
}

# ── Entry point ──────────────────────────────────────────────────────────────

case "${1:-all}" in
  sqlserver)
    ensure_sqlserver
    ;;
  postgres)
    ensure_postgres
    ;;
  all)
    ensure_sqlserver
    ensure_postgres
    ;;
  *)
    echo "Usage: $0 [sqlserver|postgres|all]" >&2
    exit 2
    ;;
esac
