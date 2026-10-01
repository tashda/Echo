#!/bin/bash
# Runs one Echo test plan and watches it.
#
#   .github/scripts/run-test-plan.sh <plan> <result-name> [stall-minutes]
#
# - The full xcodebuild output goes to <result-name>.log (upload it as an artifact); the job log
#   shows only test results, failures, the lab's own lines and a progress line every five minutes,
#   so it never hits GitHub's log limit and stays readable.
# - Watchdog: once tests have started, if nothing finishes and the lab reports nothing for
#   <stall-minutes> (default 15), it names the tests still running and stops the run; on a CI
#   runner (CI=true) it also samples the test processes into diagnostics/ first. A hang then fails in minutes with a report instead of
#   running into the job's time limit with nothing to show.
# - Exit status: xcodebuild's, or 124 after a stall.
set -uo pipefail

plan="$1"
name="$2"
stall_minutes="${3:-15}"
log="$name.log"
mkdir -p diagnostics
rm -rf "$name.xcresult" "$log"

xcodebuild test -project Echo.xcodeproj \
  -scheme Echo -testPlan "$plan" \
  -destination 'platform=macOS' \
  -resultBundlePath "$name" \
  -disable-concurrent-testing \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO ENABLE_HARDENED_RUNTIME=NO OTHER_CODE_SIGN_FLAGS='--deep' \
  > "$log" 2>&1 &
build_pid=$!

# Lines worth showing: test results, failures, errors, the lab's own lines, the final verdict.
interesting='Test [Cc]ase .*(passed|failed|skipped)|Test [Ss]uite .*(started|passed|failed)|error:|recorded an issue|\[serverlab\]|\*\* TEST|Testing (started|cancelled|failed)'
progress='Test [Cc]ase .*(passed|failed|skipped)|\[serverlab\]'

printed=0
started=""
last_progress=$(date +%s)
last_heartbeat=$(date +%s)

report_stall() {
  echo "::error::No test finished for ${stall_minutes} minutes: stopping the run."
  echo "Tests started and not finished:"
  python3 - "$log" <<'PY'
import re, sys
started, finished = {}, set()
for line in open(sys.argv[1], errors="replace"):
    m = re.search(r"Test [Cc]ase '(?:-\[\S+ )?([^'\]]+)\]?' started", line)
    if m: started[m.group(1)] = line.strip()
    m = re.search(r"Test [Cc]ase '(?:-\[\S+ )?([^'\]]+)\]?' (passed|failed|skipped)", line)
    if m: finished.add(m.group(1))
running = [name for name in started if name not in finished]
print("\n".join(f"  {name}" for name in running) or "  (none reported as started)")
PY
  echo "Last lines of the log:"
  tail -n 25 "$log" | cut -c1-240
  kill "$build_pid" 2>/dev/null
  # The test host is started by testmanagerd, not by xcodebuild, so it can only be found by name.
  # Only on a CI runner, which runs nothing else: on a Mac this would hit every Echo running there.
  if [ "${CI:-}" = "true" ]; then
    for pid in $(pgrep -f "Echo.app/Contents/MacOS/Echo|xctest" || true); do
      sample "$pid" 5 -file "diagnostics/sample-$pid.txt" >/dev/null 2>&1 && echo "Sampled process $pid into diagnostics/sample-$pid.txt"
    done
    sleep 10
    pkill -f "Echo.app/Contents/MacOS/Echo" 2>/dev/null || true
  fi
}

while kill -0 "$build_pid" 2>/dev/null; do
  sleep 20
  now=$(date +%s)
  total=$(wc -l < "$log" | tr -d ' ')
  if [ "$total" -gt "$printed" ]; then
    new=$(sed -n "$((printed + 1)),${total}p" "$log")
    printed=$total
    shown=$(printf '%s\n' "$new" | grep -E "$interesting" | cut -c1-300 || true)
    [ -n "$shown" ] && printf '%s\n' "$shown"
    if printf '%s\n' "$new" | grep -qE "$progress"; then last_progress=$now; fi
    if [ -z "$started" ] && printf '%s\n' "$new" | grep -qE "Test [Ss]uite .* started|Testing started"; then
      started=yes
      last_progress=$now
    fi
  fi
  if [ $((now - last_heartbeat)) -ge 300 ]; then
    done_count=$(grep -cE "Test [Cc]ase .*(passed|failed|skipped)" "$log" || true)
    failed_count=$(grep -cE "Test [Cc]ase .* failed" "$log" || true)
    echo "… $(date -u +%H:%M) ${done_count} tests finished, ${failed_count} failed$([ -z "$started" ] && echo ', still building')"
    last_heartbeat=$now
  fi
  if [ -n "$started" ] && [ $((now - last_progress)) -ge $((stall_minutes * 60)) ]; then
    report_stall
    wait "$build_pid" 2>/dev/null
    exit 124
  fi
done

wait "$build_pid"
status=$?
total=$(wc -l < "$log" | tr -d ' ')
[ "$total" -gt "$printed" ] && sed -n "$((printed + 1)),${total}p" "$log" | grep -E "$interesting" | cut -c1-300
echo "Finished: $(grep -cE "Test [Cc]ase .*passed" "$log" || true) passed, $(grep -cE "Test [Cc]ase .*failed" "$log" || true) failed, $(grep -cE "Test [Cc]ase .*skipped" "$log" || true) skipped (exit $status)"
if [ "$status" -ne 0 ]; then
  echo "Failures:"
  grep -E "Test [Cc]ase .* failed|error: " "$log" | cut -c1-300 | head -60
fi
exit "$status"
