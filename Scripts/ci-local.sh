#!/bin/bash
# What CI (Light) runs, on this machine: the UnitTests plan (everything that needs no server).
#
#   Scripts/ci-local.sh            run the unit tests
#   Scripts/ci-local.sh --install  run them automatically before every `git push` to dev
#   Scripts/ci-local.sh --lab      run the EchoTests plan, which sets SERVERLAB_INTEGRATION itself and starts lab servers
#                                  (needs a lab host; see echo-server-lab)
#
# Your own Echo/Configuration/Secrets.xcconfig is kept; the placeholder is only copied when it is missing.
# At the end, clean up test leftovers as described in CLAUDE.md ("End of Test Run").
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  --install)
    hook="$(git rev-parse --git-path hooks/pre-push)"
    printf '#!/bin/bash\nexec "$(git rev-parse --show-toplevel)/Scripts/ci-local.sh"\n' > "$hook"
    chmod +x "$hook"
    echo "Installed $hook"
    exit 0
    ;;
  --lab) plan=EchoTests; name=TestResults-lab ;;
  "") plan=UnitTests; name=TestResults-unit ;;
  *) echo "Unknown option $1"; exit 2 ;;
esac

Tools/fetch-postgres-tools.sh
[ -f Echo/Configuration/Secrets.xcconfig ] || cp Echo/Configuration/Secrets.xcconfig.example Echo/Configuration/Secrets.xcconfig
xcodebuild -resolvePackageDependencies -project Echo.xcodeproj -scheme Echo > /dev/null
.github/scripts/run-test-plan.sh "$plan" "$name"
