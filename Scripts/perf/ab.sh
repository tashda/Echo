#!/bin/bash
# usage: ab.sh <scenario.json> <step regex> <rounds> <ENV spec>...   e.g. ab.sh scenarios/resize6.json "resize" 2 "X=1" "ECHO_PERF_OFF=strip"
# runs each variant `rounds` times, interleaved, and prints the main thread's CPU ms per step (cpuMs) next to fps, so load from other programs shows apart from the cost
cd "${PERF_DIR:-$(dirname "$0")}"
SC=$1; RE=$2; ROUNDS=$3; shift 3
for r in $(seq 1 $ROUNDS); do
  i=0
  for v in "$@"; do
    i=$((i+1)); n=ab-$i-r$r
    ./run_variant.sh $n $SC "$v" --no-trace >/dev/null 2>&1
    PERF_DIR=$PWD python3 verify.py $n
    echo "## $v (round $r)  load $(uptime | sed 's/.*averages: //')"
    grep "^automation-frames" out/$n.stdout | grep -E "$RE" | sed -E 's/p50=[^ ]* //; s/hitches=[^ ]* //'
  done
done
