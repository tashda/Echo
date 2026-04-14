#!/bin/bash
set -euo pipefail

# The scheme pre-action expects this script to exist.
# Package updates are handled explicitly in CI and during development,
# so the default behavior here is intentionally a no-op.
exit 0
