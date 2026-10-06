#!/bin/bash
# Runs one scripted scenario against a built (DEBUG) Echo.app under Instruments' Time Profiler.
#   ECHO_APP=<path to Echo.app> Scripts/perf/run.sh <name> <script.json> <seconds>
# The app starts through `open` (so macOS grants the permissions it already has), isolated from the
# Keychain, the account and the stored data (ECHO_AUTOMATION_ISOLATED), and is traced by pid.
# Traces land in $ECHO_PERF_OUT (default: .perf/ in the current directory).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${ECHO_PERF_OUT:-$PWD/.perf}"; mkdir -p "$OUT/traces" "$OUT/out"
APP="${ECHO_APP:?set ECHO_APP to the built Echo.app}"
CONFIG="${ECHO_AUTOMATION_CONFIG:-$HERE/../../.echo-automation/config.json}"
NAME=$1; SCRIPT=$(cd "$(dirname "$2")" && pwd)/$(basename "$2"); SECS=$3
TRACE="$OUT/traces/$NAME.trace"; rm -rf "$TRACE"
pkill -f "$APP/Contents/MacOS/Echo" 2>/dev/null; sleep 1
open -n -a "$APP" --env ECHO_AUTOMATION=1 --env ECHO_AUTOMATION_ISOLATED=1 --env ECHO_AUTOMATION_SCRIPT="$SCRIPT" \
  --env ECHO_AUTOMATION_CONFIG="$CONFIG" --stdout "$OUT/out/$NAME.stdout" --stderr "$OUT/out/$NAME.stderr"
for _ in $(seq 1 30); do PID=$(pgrep -f "$APP/Contents/MacOS/Echo" | head -1); [ -n "$PID" ] && break; sleep 0.3; done
xcrun xctrace record --template "Time Profiler" --output "$TRACE" --time-limit "${SECS}s" --no-prompt --attach "$PID" > "$OUT/out/$NAME.log" 2>&1
pkill -f "$APP/Contents/MacOS/Echo"; sleep 1
echo "$TRACE"
