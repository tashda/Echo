#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE_SQLSERVER_REPO="$ROOT_DIR/vendor/sqlserver-nio"
WORKSPACE_POSTGRES_REPO="$ROOT_DIR/vendor/postgres-wire"
SIBLING_SQLSERVER_REPO="$(cd "$ROOT_DIR/.." && pwd)/sqlserver-nio"
SIBLING_POSTGRES_REPO="$(cd "$ROOT_DIR/.." && pwd)/postgres-wire"

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
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "${key}=${value}" >> "$GITHUB_ENV"
  fi
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
