#!/bin/bash
# Takes the runner off the tailnet and waits until GitHub's artifact service resolves again.
#
# The runner cannot resolve GitHub's hosts while it is on the tailnet, and for a moment after
# `tailscale down` either: an upload started straight away failed with ENOTFOUND although every
# test had passed. So: leave, flush the resolver cache, and wait (up to two minutes) until the
# hosts the upload uses answer. Never fails the job; it only reports when GitHub stays unreachable.
set -u

sudo "$(command -v tailscale)" down 2>/dev/null || true
sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

hosts="api.github.com results-receiver.actions.githubusercontent.com"
for attempt in $(seq 1 40); do
  unreachable=""
  for host in $hosts; do
    curl -sS -o /dev/null --max-time 5 "https://$host" 2>/dev/null || unreachable="$unreachable $host"
  done
  if [ -z "$unreachable" ]; then
    echo "Off the tailnet; GitHub answers (after $attempt checks)."
    exit 0
  fi
  sleep 3
done
echo "::warning::GitHub still unreachable 2 minutes after leaving the tailnet:$unreachable"
scutil --dns | head -40
exit 0
