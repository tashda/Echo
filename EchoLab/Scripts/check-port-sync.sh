#!/bin/zsh
# Lists Design Lab files in Echo that differ from their copy in Echo Lab (ignoring the
# removed #if DEBUG wrapper), or that have no copy yet. Run from the repo root.
src=Echo/Sources/Features/DesignLab
dst=EchoLab/Sources/EchoLab/Ported
for f in $src/*.swift; do
  name=${f:t}
  copy=$dst/$name
  if [[ ! -f $copy ]]; then echo "NOT COPIED  $name"; continue; fi
  [[ $name == DesignLabWindow.swift ]] && continue   # edited on purpose; see PORTING.md
  if ! diff -q <(grep -v -x -e '#if DEBUG' -e '#endif' $f) <(grep -v -x -e '#if DEBUG' -e '#endif' $copy) >/dev/null; then
    echo "CHANGED     $name"
  fi
done
