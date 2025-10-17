#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=${POSTGRES_BENCHMARK_ENV_FILE:-postgres_benchmark.env}
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  export \
    ECHO_POSTGRES_HOST \
    ECHO_POSTGRES_PORT \
    ECHO_POSTGRES_DATABASE \
    ECHO_POSTGRES_USERNAME \
    ECHO_POSTGRES_PASSWORD
  [[ -n ${ECHO_POSTGRES_SSL+x} ]] && export ECHO_POSTGRES_SSL
  [[ -n ${ECHO_POSTGRES_BASE_QUERY+x} ]] && export ECHO_POSTGRES_BASE_QUERY
fi

echo "Postgres benchmark target: ${ECHO_POSTGRES_HOST:-<unset>}:${ECHO_POSTGRES_PORT:-<unset>}/${ECHO_POSTGRES_DATABASE:-<unset>}"

if [[ "${ECHO_POSTGRES_HOST:-}" == "" || "${ECHO_POSTGRES_PORT:-}" == "" || \
      "${ECHO_POSTGRES_DATABASE:-}" == "" || "${ECHO_POSTGRES_USERNAME:-}" == "" || \
      "${ECHO_POSTGRES_PASSWORD:-}" == "" ]]; then
  cat <<'MSG'
Postgres benchmark skipped: please set the required environment variables.
You can either export them in your shell or create a local "postgres_benchmark.env"
file (not committed) with lines such as:
  ECHO_POSTGRES_HOST=tippr.dk
  ECHO_POSTGRES_PORT=5432
  ECHO_POSTGRES_DATABASE=tippr
  ECHO_POSTGRES_USERNAME=rundeckuser
  ECHO_POSTGRES_PASSWORD=...
Optional:
  ECHO_POSTGRES_SSL=true
  ECHO_POSTGRES_BASE_QUERY="SELECT * FROM public.fixture"
MSG
  exit 0
fi

SCHEME=${SCHEME:-EchoTests}
DESTINATION=${DESTINATION:-"platform=macOS"}
TEST_IDENTIFIER="EchoTests/PostgresStreamingBenchmarkTests/testPostgresStreamingBenchmarks"

ECHO_POSTGRES_HOST="$ECHO_POSTGRES_HOST" \
ECHO_POSTGRES_PORT="$ECHO_POSTGRES_PORT" \
ECHO_POSTGRES_DATABASE="$ECHO_POSTGRES_DATABASE" \
ECHO_POSTGRES_USERNAME="$ECHO_POSTGRES_USERNAME" \
ECHO_POSTGRES_PASSWORD="$ECHO_POSTGRES_PASSWORD" \
ECHO_POSTGRES_SSL="${ECHO_POSTGRES_SSL:-}" \
ECHO_POSTGRES_BASE_QUERY="${ECHO_POSTGRES_BASE_QUERY:-}" \
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  test \
  -only-testing:"$TEST_IDENTIFIER" "$@"
