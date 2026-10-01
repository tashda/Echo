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

# A finished test, in XCTest's format ("Test Case '-[Suite test]' passed (0.1 seconds).") or in
# Swift Testing's ("✔ Test name() passed after 0.1 seconds.", "✘ Test name() failed after …").
finished_test="Test [Cc]ase .*' (passed|failed|skipped)|Test .*(passed|failed) after [0-9.]+ seconds|Test [^ ]+ skipped"
# Lines worth showing: test results, failures, errors, the lab's own lines, the final verdict.
interesting="$finished_test|Test [Ss]uite .*(started|passed|failed)|Suite .*(passed|failed) after|error:|recorded an issue|\\[serverlab\\]|\\*\\* TEST|Testing (started|cancelled|failed)"
progress="$finished_test|\\[serverlab\\]"

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
    m = re.search(r"Test [Cc]ase '(?:-\[\S+ )?([^'\]]+)\]?' started", line) or re.search(r"Test (\S.*?) started\.", line)
    if m: started[m.group(1)] = line.strip()
    m = re.search(r"Test [Cc]ase '(?:-\[\S+ )?([^'\]]+)\]?' (passed|failed|skipped)", line) or re.search(r"Test (\S.*?) (?:passed|failed) after", line)
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
    done_count=$(grep -cE "$finished_test" "$log" || true)
    failed_count=$(grep -cE "Test [Cc]ase .*' failed|Test .* failed after" "$log" || true)
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
# The totals and failures come from the result bundle, which counts XCTest and Swift Testing alike;
# the log is only the fallback when there is no bundle (the build failed or the run was stopped).
if xcrun xcresulttool get test-results summary --path "$name.xcresult" > "$name.summary.json" 2>/dev/null; then
  python3 - "$name.summary.json" "$status" <<'SUMMARY'
import json, sys
d = json.load(open(sys.argv[1]))
print("Finished: %s passed, %s failed, %s skipped, %s expected failures of %s (%s, exit %s)" % (
    d.get("passedTests", 0), d.get("failedTests", 0), d.get("skippedTests", 0),
    d.get("expectedFailures", 0), d.get("totalTestCount", 0), d.get("result", "?"), sys.argv[2]))
for failure in d.get("testFailures", [])[:60]:
    text = " ".join(failure.get("failureText", "").split())[:400]
    print("::error title=%s::%s" % (failure.get("testIdentifierString", "?"), text))
SUMMARY
else
  echo "Finished without a result bundle (exit $status): $(grep -cE "$finished_test" "$log" || true) tests reported in the log"
fi
if [ "$status" -ne 0 ]; then
  echo "Failures and errors in the log:"
  grep -E "Test [Cc]ase .*' failed|Test .* failed after|recorded an issue|error: |\\*\\* TEST .*FAILED" "$log" | cut -c1-300 | head -60
fi
exit "$status"
