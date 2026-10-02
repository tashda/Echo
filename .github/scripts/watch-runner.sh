#!/bin/bash
# Records, once a minute, whether this CI runner still reaches GitHub and testlab, with its memory,
# load and how many tests have finished:
#
#   [watch] 19:42 github=200/0.09s results=404/0.11s testlab=up tailscale=Running mem-free=41% load=3.10 tests=210
#
#   .github/scripts/watch-runner.sh <test-log> <finished-test-pattern> <record-name>
#
# Each line goes to the job log, to diagnostics/runner-watch.log and, when the runner can reach
# testlab, to testlab's ~/ci-watch/<record-name>.log. That last copy matters: a runner that "lost
# communication with the server" uploads no log at all, and the record on testlab still shows when
# GitHub stopped answering and whether the tailnet, memory or load had anything to do with it.
# For curl, 000 means no answer: exit 6 is a name that did not resolve, 7 a refused connection,
# 28 a timeout.
set -u
test_log="$1"
finished_test="$2"
record="$3"
mkdir -p diagnostics

probe() {
  local result
  result=$(curl -s -o /dev/null -w '%{http_code}/%{time_total}s' --max-time 10 "$1" 2>/dev/null)
  local status=$?
  [ "$status" -eq 0 ] && echo "$result" || echo "000(exit $status)"
}

ssh -o BatchMode=yes -o ConnectTimeout=5 testlab \
  "mkdir -p ci-watch && find ci-watch -name '*.log' -mtime +14 -delete" 2>/dev/null || true

while true; do
  github=$(probe https://api.github.com)
  results=$(probe https://results-receiver.actions.githubusercontent.com)
  testlab=$(nc -z -G 5 "$(ssh -G testlab | awk '/^hostname /{print $2}')" 22 >/dev/null 2>&1 && echo up || echo down)
  tailscale=$(tailscale status --json 2>/dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin).get("BackendState", "?"))' 2>/dev/null || echo none)
  memory=$(memory_pressure -Q 2>/dev/null | grep -oE '[0-9]+%' | head -1)
  load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
  tests=$(grep -cE "$finished_test" "$test_log" 2>/dev/null || true)
  line="[watch] $(date -u +%H:%M) github=$github results=$results testlab=$testlab tailscale=$tailscale mem-free=${memory:-?} load=${load:-?} tests=$tests"
  echo "$line"
  echo "$line" >> diagnostics/runner-watch.log
  printf '%s\n' "$line" | ssh -o BatchMode=yes -o ConnectTimeout=5 testlab "cat >> ci-watch/$record.log" 2>/dev/null || true
  sleep 60
done
