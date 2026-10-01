#!/bin/bash
# Puts the PostgreSQL client tools Echo bundles (pg_dump, pg_restore, pg_dumpall, psql) into
# Tools/PostgresTools/, from the echo-libraries release. The build copies them to
# Contents/SharedSupport/PostgresTools/, where they load libpq and its libraries from the
# frameworks the echo-libraries package embeds in Contents/Frameworks/.
#
# Keep RELEASE equal to the echo-libraries version in Package.resolved: the tools and the
# frameworks come from the same build. SHA256 is PostgresTools.zip's line in the release's
# checksums.txt.
set -euo pipefail

RELEASE="1.1.0"
SHA256="cfa3b347967e25a68f391ff0ce74577efda8f3b1337d3d229daaa586149ffc95"
URL="https://github.com/tashda/echo-libraries/releases/download/$RELEASE/PostgresTools.zip"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Tools/PostgresTools"
STAMP="$DEST/.release"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$RELEASE $SHA256" ]; then
  echo "PostgreSQL tools $RELEASE already in $DEST"
  exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fsSL --retry 3 -o "$work/PostgresTools.zip" "$URL"
actual="$(shasum -a 256 "$work/PostgresTools.zip" | cut -d' ' -f1)"
if [ "$actual" != "$SHA256" ]; then
  echo "PostgresTools.zip checksum is $actual, expected $SHA256" >&2
  exit 1
fi

/usr/bin/ditto -x -k "$work/PostgresTools.zip" "$work/unpacked"
src="$work/unpacked"
[ -d "$src/PostgresTools" ] && src="$src/PostgresTools"
for tool in pg_dump pg_restore pg_dumpall psql; do
  [ -x "$src/$tool" ] || { echo "$tool missing from PostgresTools.zip" >&2; exit 1; }
done

rm -rf "$DEST"
mkdir -p "$DEST"
cp -p "$src"/pg_dump "$src"/pg_restore "$src"/pg_dumpall "$src"/psql "$DEST/"
echo "$RELEASE $SHA256" > "$STAMP"
echo "PostgreSQL tools $RELEASE in $DEST"
