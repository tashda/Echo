#!/usr/bin/env bash
# End-to-end check of the hatch command: project, ticket, agent flow, claims, sync (dry run), status.
# Usage: tools/smoke.sh [path to hatch binary]
set -euo pipefail
H="${1:-.build/debug/hatch}"
export HATCH_HOME="$(mktemp -d)"
trap 'rm -rf "$HATCH_HOME"' EXIT
expect() { grep -q "$1" <<<"$2" || { echo "FAIL: expected '$1' in:"; echo "$2"; exit 1; }; }

out=$($H init --config examples/project.json --key acme);                 expect "registered" "$out"
out=$($H ticket new --type tweak --title "Rename Connect button" --submit);     expect "Checking" "$out"
out=$($H admin move new-1 ready --as agent);                                    expect "Ready" "$out"
out=$($H next);                                                                 expect "build" "$out"
out=$($H take new-1 --agent "Agent on new-1" --no-workspace);                   expect "Rules for this task" "$out"
out=$($H plan new-1 --files "Acme/Sources/Features/Connections/ConnectButton.swift"); expect "Claim granted" "$out"
out=$($H ticket new --type tweak --title "Connect button colour" --submit);     expect "Created" "$out"
out=$($H admin move new-2 ready --as agent >/dev/null; $H take new-2 --agent "Agent on new-2" --no-workspace >/dev/null; $H plan new-2 --files "Acme/Sources/Features/Connections/**"); expect "claimed by" "$out"
out=$($H sync push --dry-run);                                                  expect "done" "$out"
out=$($H status);                                                               expect "Sync:" "$out"
out=$($H ticket list --json);                                                   expect "Rename Connect button" "$out"
out=$($H search "connect button");                                              expect "Connect" "$out"
if [ -f "${LAB_STATE:-/nonexistent}" ]; then out=$($H import-labs --file "$LAB_STATE"); expect "pagesSeen" "$out"; fi
echo "smoke ok"
