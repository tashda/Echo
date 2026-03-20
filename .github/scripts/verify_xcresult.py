#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path


def load_summary(path: Path) -> dict:
    command = [
        "xcrun",
        "xcresulttool",
        "get",
        "test-results",
        "summary",
        "--path",
        str(path),
        "--compact",
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "xcresulttool failed")
    return json.loads(result.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify that an xcresult bundle executed real tests.")
    parser.add_argument("--path", required=True, help="Path to the .xcresult bundle")
    parser.add_argument("--label", required=True, help="Human-readable job label")
    parser.add_argument("--min-executed", type=int, default=1, help="Minimum non-skipped tests required")
    args = parser.parse_args()

    result_path = Path(args.path)
    if not result_path.exists():
        print(f"{args.label}: missing xcresult bundle at {result_path}", file=sys.stderr)
        return 1

    try:
        summary = load_summary(result_path)
    except Exception as error:
        print(f"{args.label}: failed to read xcresult summary: {error}", file=sys.stderr)
        return 1

    total = int(summary.get("totalTestCount") or 0)
    skipped = int(summary.get("skippedTests") or 0)
    passed = int(summary.get("passedTests") or 0)
    failed = int(summary.get("failedTests") or 0)
    expected_failures = int(summary.get("expectedFailures") or 0)
    executed = total - skipped

    print(
        f"{args.label}: total={total} executed={executed} passed={passed} "
        f"failed={failed} skipped={skipped} expected_failures={expected_failures}"
    )

    if executed < args.min_executed:
        print(
            f"{args.label}: executed only {executed} tests, expected at least {args.min_executed}",
            file=sys.stderr,
        )
        return 1

    if total > 0 and skipped == total:
        print(f"{args.label}: every discovered test was skipped", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
