#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>
#
# Thin wrapper so the orchestrator reaches the dependency-free Node linter
# only through an allowlisted *.sh script.

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<'EOF'
Usage:
  lint-review-manifest.sh <path/to/review-manifest.json>

Validates one security-review package manifest against
contracts/review-manifest.schema.json and the cross-field, approval, and
retained-evidence rules in contracts/REVIEW-PROVENANCE.md. Prints the
mechanically derived classification on success. Requires node.
EOF
}

die() {
    printf 'lint-review-manifest: ERROR: %s\n' "$*" >&2
    exit 1
}

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

case $1 in
    -h | --help)
        usage
        exit 0
        ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) ||
    die "cannot resolve script directory"
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P) ||
    die "cannot resolve repository root"

linter="$repository_root/scripts/lint-review-manifest.mjs"
[ -f "$linter" ] || die "linter not found: scripts/lint-review-manifest.mjs"

command -v node >/dev/null 2>&1 ||
    die "node is required to lint review manifests but was not found in PATH"

exec node "$linter" "$1"
