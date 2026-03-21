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

ensure_sqlserver() {
  local output
  output="$(swift run --package-path "$SQLSERVER_REPO" sqlserver-test-fixture --require-adventureworks)"
  echo "$output"
  write_summary "SQL Server" "$output"
  append_env "USE_DOCKER" "1"
  append_env "ECHO_USE_PACKAGE_FIXTURES" "1"
  append_env "ECHO_MSSQL_FIXTURE_VALIDATED" "1"
  append_env "ECHO_MSSQL_PORT" "$(echo "$output" | awk -F= '$1=="port" {print $2}')"
  append_env "ECHO_MSSQL_FIXTURE_VERSION" "$(echo "$output" | awk -F= '$1=="fixture_version" {print $2}')"
}

ensure_postgres() {
  local output
  output="$(swift run --package-path "$POSTGRES_REPO" postgres-test-fixture)"
  local port
  port="$(echo "$output" | awk -F= '$1=="port" {print $2}')"
  echo "$output"
  write_summary "Postgres" "$output"
  append_env "USE_DOCKER" "1"
  append_env "ECHO_USE_PACKAGE_FIXTURES" "1"
  append_env "ECHO_PG_FIXTURE_VALIDATED" "1"
  append_env "ECHO_PG_HOST" "127.0.0.1"
  append_env "ECHO_PG_PORT" "$port"
  append_env "ECHO_PG_DATABASE" "postgres"
  append_env "ECHO_PG_USER" "postgres"
  append_env "ECHO_PG_PASSWORD" "postgres"
  append_env "TEST_PG_HOST" "127.0.0.1"
  append_env "TEST_PG_PORT" "$port"
  append_env "TEST_PG_DATABASE" "postgres"
  append_env "TEST_PG_USER" "postgres"
  append_env "TEST_PG_PASSWORD" "postgres"
  append_env "ECHO_PG_FIXTURE_VERSION" "$(echo "$output" | awk -F= '$1=="fixture_version" {print $2}')"
  prepare_postgres_backup_database "$port"
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
