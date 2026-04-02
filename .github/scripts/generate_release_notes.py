#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import subprocess
from collections import OrderedDict
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Category:
    name: str
    patterns: tuple[str, ...]


# Patterns that identify test-only files (used to reroute commits to Testing & CI)
TEST_FILE_PATTERNS: dict[str, tuple[str, ...]] = {
    "echo": ("EchoTests/", ".xctestplan"),
    "sqlserver-nio": ("Tests/", "Sources/SQLServerKitTesting/", "Sources/SQLServerFixtureTool/"),
    "postgres-wire": ("Tests/", "Sources/PostgresKitTesting/", "Sources/PostgresFixtureTool/"),
    "echosense": ("Tests/",),
}

# Subject-line patterns that indicate a bug fix
FIX_PATTERNS = re.compile(
    r"^(fix|bug|patch|hotfix|resolve|correct)\b",
    re.IGNORECASE,
)

REPO_CATEGORIES: dict[str, list[Category]] = {
    "sqlserver-nio": [
        Category("TDS Protocol", ("Sources/SQLServerTDS/",)),
        Category("Client & Connections", ("Sources/SQLServerKit/Client/", "Sources/SQLServerKit/Connection/")),
        Category("Metadata & Admin APIs", ("Sources/SQLServerKit/Metadata/", "Sources/SQLServerKit/Admin/", "Sources/SQLServerKit/Schema/")),
        Category("Transactions & Queries", ("Sources/SQLServerKit/Transactions/", "Sources/SQLServerKit/Query", "Sources/SQLServerKit/Statement")),
        Category("Testing & CI", ("Tests/", "Sources/SQLServerKitTesting/", "Sources/SQLServerFixtureTool/", ".github/", "scripts/")),
        Category("CI & Release", (".github/", "Package.swift", "scripts/")),
        Category("Documentation", ("README", "TEST_FIXTURES.md", "CHANGELOG", "docs/")),
    ],
    "postgres-wire": [
        Category("Wire Protocol", ("Sources/PostgresWire/",)),
        Category("Client APIs", ("Sources/PostgresKit/",)),
        Category("Testing & CI", ("Tests/", "Sources/PostgresKitTesting/", "Sources/PostgresFixtureTool/", ".github/", "scripts/")),
        Category("CI & Release", (".github/", "Package.swift", "scripts/")),
        Category("Documentation", ("README", "TEST_FIXTURES.md", "CHANGELOG", "docs/")),
    ],
    "echo": [
        Category("Query Workspace", ("Echo/Sources/Features/QueryWorkspace/",)),
        Category("Connection & Database Engine", ("Echo/Sources/Core/DatabaseEngine/", "Echo/Sources/Features/ConnectionVault/")),
        Category("App Host & Windowing", ("Echo/Sources/Features/AppHost/", "Echo/Sources/Shared/ActivityEngine/")),
        Category("Design System & Shared UI", ("Echo/Sources/Shared/DesignSystem/", "Echo/Sources/UI/")),
        Category("Operations & Tooling", ("Echo/Sources/Features/Maintenance/", "Echo/Sources/Features/Import/", "Echo/Sources/Features/BackupRestore/", "Echo/Sources/Features/ActivityMonitor/")),
        Category("Testing & CI", ("EchoTests/", ".xctestplan", "TEST_FIXTURES.md", ".github/")),
        Category("Documentation", ("AGENTS.md", "CLAUDE.md", "SSMS_FEATURE_GAP.md", "VISUAL_GUIDELINES.md")),
    ],
    "echosense": [
        Category("Shared Database Models", ("Sources/",)),
        Category("Testing & CI", ("Tests/", ".github/", "Package.swift", "scripts/")),
        Category("Documentation", ("README", "CHANGELOG", "docs/")),
    ],
}

# Name of the testing category — commits touching only test files are rerouted here
TESTING_CATEGORY = "Testing & CI"


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def git_lines(*args: str) -> list[str]:
    output = git(*args)
    return [line for line in output.splitlines() if line.strip()]


def path_matches(path: str, pattern: str) -> bool:
    if pattern.startswith("*."):
        return path.endswith(pattern[1:])
    return path.startswith(pattern) or path == pattern


def is_test_only(files: list[str], repo_key: str) -> bool:
    """Return True if every file in the commit matches a test pattern."""
    test_patterns = TEST_FILE_PATTERNS.get(repo_key, ())
    if not test_patterns or not files:
        return False
    return all(
        any(path_matches(f, p) for p in test_patterns)
        for f in files
    )


def is_fix(subject: str) -> bool:
    return bool(FIX_PATTERNS.search(subject))


def categorize(files: list[str], repo_key: str) -> str:
    categories = REPO_CATEGORIES.get(repo_key, [])
    best_name = "Other Changes"
    best_score = -1
    for category in categories:
        score = sum(1 for path in files for pattern in category.patterns if path_matches(path, pattern))
        if score > best_score:
            best_name = category.name
            best_score = score
    return best_name


def commit_range(previous_tag: str | None) -> str | None:
    if previous_tag:
        verified = subprocess.run(["git", "rev-parse", "--verify", "--quiet", previous_tag], capture_output=True, text=True)
        if verified.returncode == 0:
            return f"{previous_tag}..HEAD"
    return None


@dataclass
class CategoryBucket:
    features: list[str] = field(default_factory=list)
    fixes: list[str] = field(default_factory=list)

    @property
    def empty(self) -> bool:
        return not self.features and not self.fixes


def load_commits(range_spec: str | None, repo_key: str) -> tuple[OrderedDict[str, CategoryBucket], int]:
    if range_spec:
        hashes = git_lines("rev-list", "--reverse", "--no-merges", range_spec)
    else:
        hashes = git_lines("rev-list", "--reverse", "--max-count=30", "--no-merges", "HEAD")

    grouped: OrderedDict[str, CategoryBucket] = OrderedDict()
    for commit_hash in hashes:
        subject = git("show", "-s", "--format=%s", commit_hash)
        files = git_lines("show", "--format=", "--name-only", "--diff-filter=ACDMRTUXB", commit_hash)

        # Route test-only commits to Testing & CI
        if is_test_only(files, repo_key):
            category = TESTING_CATEGORY
        else:
            category = categorize(files, repo_key)

        bucket = grouped.setdefault(category, CategoryBucket())
        if is_fix(subject):
            bucket.fixes.append(subject)
        else:
            bucket.features.append(subject)

    return grouped, len(hashes)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-key", required=True, choices=sorted(REPO_CATEGORIES.keys()))
    parser.add_argument("--repo-name", required=True)
    parser.add_argument("--new-tag", required=True)
    parser.add_argument("--previous-tag", default="")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    previous_tag = args.previous_tag.strip() or None
    range_spec = commit_range(previous_tag)
    if range_spec is None:
        previous_tag = None
    grouped, commit_count = load_commits(range_spec, args.repo_key)
    repository = os.environ.get("GITHUB_REPOSITORY", "")

    lines: list[str] = [
        f"# {args.repo_name} {args.new_tag}",
        "",
        "## Summary",
        "",
    ]

    if previous_tag:
        lines.append(f"- Release range: `{previous_tag}` -> `{args.new_tag}`")
    else:
        lines.append(f"- Release range: initial curated release snapshot for `{args.new_tag}`")
    lines.append(f"- Commits included: {commit_count}")
    if repository and previous_tag:
        lines.append(f"- Compare: https://github.com/{repository}/compare/{previous_tag}...{args.new_tag}")
    lines.extend(["", "## Detailed Changes", ""])

    if not grouped or all(b.empty for b in grouped.values()):
        lines.extend(["- No application changes were detected in the selected range.", ""])
    else:
        for category, bucket in grouped.items():
            if bucket.empty:
                continue
            lines.extend([f"### {category}", ""])
            if bucket.features:
                if bucket.fixes:
                    lines.append("**Features & Improvements**")
                    lines.append("")
                for subject in bucket.features:
                    lines.append(f"- {subject}")
                lines.append("")
            if bucket.fixes:
                if bucket.features:
                    lines.append("**Bug Fixes**")
                    lines.append("")
                for subject in bucket.fixes:
                    lines.append(f"- {subject}")
                lines.append("")

    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines).rstrip() + "\n")


if __name__ == "__main__":
    main()
