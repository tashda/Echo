#!/usr/bin/env bash
# TEMPORARY: GitHub Actions does not start jobs in the private hatch repository (no runner is assigned, even for a
# one-line job). Until that is fixed in the account's Actions/billing settings, this copies the current tree into a
# CI-only folder on the Echo working branch, where the macOS runner works, so the app can be compiled there.
# Development stays in this repository. Remove .hatch-ci-mirror/ and its workflow from Echo when no longer needed.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
ECHO="${ECHO_CLONE:-/home/user/Echo}"
cd "$ECHO"
git checkout -q claude/echo-labs-features-wmwnbv
rm -rf .hatch-ci-mirror && mkdir -p .hatch-ci-mirror/hatch   # folder must be called "hatch": SwiftPM names path dependencies by folder
(cd "$SRC" && tar --exclude=.git --exclude=.build -cf - .) | tar -xf - -C .hatch-ci-mirror/hatch
mkdir -p .github/workflows
cp "$SRC/tools/hatch-ci-mirror.yml" .github/workflows/hatch-ci-mirror.yml
git add -A -f .hatch-ci-mirror .github/workflows/hatch-ci-mirror.yml   # -f: Echo ignores *.md, the tests need fixtures
if git diff --cached --quiet; then echo "mirror already up to date"; exit 0; fi
git -c user.name=Claude -c user.email=noreply@anthropic.com commit -q -m "ci(hatch): mirror of tashda/hatch for macOS compile checks (temporary)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01MEet2ygQqjbG5YiY16i5aB"
git push -q origin claude/echo-labs-features-wmwnbv
echo "mirrored $(cd "$SRC" && git rev-parse --short HEAD)"
