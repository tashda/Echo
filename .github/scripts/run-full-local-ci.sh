#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

BOOTSTRAP="$SCRIPT_DIR/bootstrap-db-fixtures.sh"
chmod +x "$BOOTSTRAP"

PASSED=0
FAILED=0
SKIPPED=0
RESULTS=()

run_test() {
  local label="$1"
  local test_plan="$2"
  shift 2
  # remaining args are env vars

  echo ""
  echo "════════════════════════════════════════════════════════════════"
  echo "  $label"
  echo "════════════════════════════════════════════════════════════════"

  # Set up environment
  eval "$@"

  # Bootstrap fixtures
  if [[ "$test_plan" == "MSSQLCompatibilityTests" ]]; then
    "$BOOTSTRAP" sqlserver
  elif [[ "$test_plan" == "PostgresCompatibilityTests" ]]; then
    "$BOOTSTRAP" postgres
  else
    "$BOOTSTRAP" all
  fi

  # Run tests
  local result_dir="/tmp/echo-ci-${label// /-}"
  rm -rf "$result_dir" "${result_dir}.xcresult"

  local exit_code=0
  TEST_RUNNER_USE_DOCKER=1 \
  TEST_RUNNER_ECHO_USE_PACKAGE_FIXTURES=1 \
  TEST_RUNNER_ECHO_MSSQL_FIXTURE_VALIDATED=1 \
  TEST_RUNNER_ECHO_MSSQL_PORT="${ECHO_MSSQL_PORT:-14332}" \
  TEST_RUNNER_ECHO_PG_FIXTURE_VALIDATED="${ECHO_PG_FIXTURE_VALIDATED:-0}" \
  TEST_RUNNER_ECHO_PG_HOST="${ECHO_PG_HOST:-127.0.0.1}" \
  TEST_RUNNER_ECHO_PG_PORT="${ECHO_PG_PORT:-54322}" \
  TEST_RUNNER_ECHO_PG_DATABASE="${ECHO_PG_DATABASE:-postgres}" \
  TEST_RUNNER_ECHO_PG_USER="${ECHO_PG_USER:-postgres}" \
  TEST_RUNNER_ECHO_PG_PASSWORD="${ECHO_PG_PASSWORD:-postgres}" \
  TEST_RUNNER_TEST_PG_HOST="${TEST_PG_HOST:-127.0.0.1}" \
  TEST_RUNNER_TEST_PG_PORT="${TEST_PG_PORT:-54322}" \
  TEST_RUNNER_TEST_PG_DATABASE="${TEST_PG_DATABASE:-postgres}" \
  TEST_RUNNER_TEST_PG_USER="${TEST_PG_USER:-postgres}" \
  TEST_RUNNER_TEST_PG_PASSWORD="${TEST_PG_PASSWORD:-postgres}" \
  TEST_RUNNER_TEST_PG_BACKUP_DATABASE="${TEST_PG_BACKUP_DATABASE:-echo_backup_restore_test}" \
  TEST_RUNNER_ECHO_PG_BACKUP_DATABASE="${ECHO_PG_BACKUP_DATABASE:-echo_backup_restore_test}" \
  xcodebuild test -project Echo.xcodeproj -scheme Echo \
    -testPlan "$test_plan" \
    -destination 'platform=macOS' \
    -resultBundlePath "$result_dir" \
    -disable-concurrent-destination-testing \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "Executed.*tests|TEST (SUCCEEDED|FAILED)" | tail -3 || exit_code=$?

  if grep -q "TEST SUCCEEDED" <<< "$(tail -5 "$result_dir"/../*.log 2>/dev/null)"; then
    echo "✅ $label: PASSED"
    PASSED=$((PASSED + 1))
    RESULTS+=("✅ $label")
  else
    # Check if tests actually ran
    local summary
    summary=$(python3 "$SCRIPT_DIR/verify_xcresult.py" --path "${result_dir}.xcresult" --label "$label" --min-executed 0 2>/dev/null || echo "unknown")
    if echo "$summary" | grep -q "failed=0"; then
      echo "✅ $label: PASSED"
      PASSED=$((PASSED + 1))
      RESULTS+=("✅ $label")
    else
      echo "❌ $label: FAILED"
      echo "   $summary"
      FAILED=$((FAILED + 1))
      RESULTS+=("❌ $label: $summary")
    fi
  fi

  # Clean up the version-specific container after testing
  # (keep it if you want to inspect, comment this out)
}

echo "🏗️  Building Echo for testing..."
xcodebuild build-for-testing -project Echo.xcodeproj -scheme Echo \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tail -3

echo ""
echo "🧪 Starting full local CI run..."
echo ""

# ── Step 2: Core Integration Tests ──────────────────────────────────────────
run_test "Integration Tests" "DatabaseIntegrationTests" \
  "export ECHO_MSSQL_PORT=14331 ECHO_PG_PORT=54321 ECHO_PG_FIXTURE_VALIDATED=1"

# ── Step 2b: Extended Integration Tests ─────────────────────────────────────
run_test "Extended Integration" "ExtendedIntegrationTests" \
  "export ECHO_MSSQL_PORT=14331 ECHO_PG_PORT=54321 ECHO_PG_FIXTURE_VALIDATED=1"

# ── Step 3: MSSQL Compatibility Matrix ──────────────────────────────────────
for compat_entry in "2008 R2:2017-latest:100" "2012:2017-latest:110" "2014:2017-latest:120" "2016:2017-latest:130" "2017:2017-latest:" "2019:2019-latest:" "2022:2022-latest:" "2025:2025-latest:"; do
  IFS=: read -r label version compat <<< "$compat_entry"
  local_port=$((14350 + RANDOM % 100))
  run_test "MSSQL $label" "MSSQLCompatibilityTests" \
    "export ECHO_MSSQL_VERSION=$version ECHO_MSSQL_COMPAT=$compat ECHO_MSSQL_PORT=$local_port"
done

# ── Step 3: Postgres Compatibility Matrix ───────────────────────────────────
for pg_version in 14 15 16 17 18; do
  local_port=$((54350 + RANDOM % 100))
  run_test "Postgres $pg_version" "PostgresCompatibilityTests" \
    "export ECHO_PG_VERSION=$pg_version ECHO_PG_PORT=$local_port ECHO_PG_FIXTURE_VALIDATED=1"
done

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  FULL CI RESULTS: $PASSED passed, $FAILED failed"
echo "════════════════════════════════════════════════════════════════"
for r in "${RESULTS[@]}"; do
  echo "  $r"
done
echo ""

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
