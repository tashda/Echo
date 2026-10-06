#!/bin/bash
# Interactive session with a running Echo:
#   sess.sh start [server...]   launch (connects the servers)      sess.sh stop
#   sess.sh cmd '<json step>' ...   run steps (waits for each to finish; prints the app's lines)
#   sess.sh ax [maxDepth] [windowIndex] [grep]   the accessibility tree
# PERF_DIR: where scripts/, out/ and the compiled axdump live (default: next to this file); ECHO_APP: the Echo.app to run.
P=${PERF_DIR:-$(cd "$(dirname "$0")" && pwd)}
APPDIR=${ECHO_APP:-${APPDIR:-$P/../../.build/DD/Build/Products/Debug/Echo.app}}
mkdir -p $P/out $P/scripts
CMDS=$P/out/session.cmds; OUT=$P/out/session.stdout
pid() { pgrep -f "$APPDIR/Contents/MacOS/Echo" | head -1; }
case $1 in
 start)
  shift; pkill -f "$APPDIR/Contents/MacOS/Echo" 2>/dev/null; sleep 1; : > $CMDS; : > $OUT
  CONN=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "$@")
  echo "{\"connect\":$CONN,\"steps\":[]}" > $P/scripts/session.json
  open -g -n -a "$APPDIR" --env ECHO_AUTOMATION=1 --env ECHO_AUTOMATION_ISOLATED=1 --env ECHO_AUTOMATION_SCRIPT=$P/scripts/session.json \
    --env ECHO_AUTOMATION_COMMANDS=$CMDS --env ECHO_AUTOMATION_CONFIG=/Users/k/Development/Echo/.echo-automation/config.json --stdout $OUT --stderr $P/out/session.stderr
  for i in $(seq 1 120); do grep -q "commands listening" $OUT 2>/dev/null && break; sleep 0.5; done; echo "ready pid $(pid)";;
 stop) pkill -f "$APPDIR/Contents/MacOS/Echo";;
 cmd)
  shift
  for step in "$@"; do
    N=$(wc -l < $CMDS | tr -d ' '); echo "$step" >> $CMDS; N=$((N+1))
    for i in $(seq 1 600); do grep -q "commands done $N\$" $OUT && break; sleep 0.2; done
  done
  grep -E "^automation-(ui|press|click|scroll|menu|views|type)" $OUT | tail -${TAIL:-40};;
 ax) AXSKIP=${AXSKIP:-workspace-sidebar} $P/axdump $(pid) ${2:-30} ${3:-0} 2>&1 | { if [ -n "$4" ]; then grep -E "$4"; else cat; fi; };;
esac
