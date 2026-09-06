#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>
#
# Print retained_evidence[] manifest fragments for every regular file under a
# security-review package's evidence/ directory. Read-only; hashes are an
# attestation input, not proof that the recorded command ran.

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<'EOF'
Usage:
  hash-evidence.sh <package-dir>

Walks <package-dir>/evidence/ and prints a JSON array of retained_evidence[]
objects ({"path","sha256","command_id"}) sorted by path. Only regular files
are hashed; a symbolic link anywhere under evidence/ is an error, as is a
file that is not inside an evidence/APPROVAL-NNN/ directory. Paste the array
into review-manifest.json as execution.retained_evidence.
EOF
}

die() {
    printf 'hash-evidence: ERROR: %s\n' "$*" >&2
    exit 1
}

json_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
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

package_dir=$1
[ -d "$package_dir" ] || die "package directory not found: $package_dir"
package_dir=$(CDPATH= cd -- "$package_dir" && pwd -P) ||
    die "cannot resolve package directory"
evidence_dir="$package_dir/evidence"

[ -e "$evidence_dir" ] || die "missing evidence/ directory in $package_dir"
[ ! -L "$evidence_dir" ] || die "evidence/ must not be a symbolic link"
[ -d "$evidence_dir" ] || die "evidence/ is not a directory"

symlink=$(find "$evidence_dir" -type l -print -quit)
[ -z "$symlink" ] || die "symbolic link under evidence/ is not retainable: ${symlink#"$package_dir/"}"

command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"

# Validate and hash everything before printing so a refusal never leaves a
# partial JSON array on stdout.
entries=""
while IFS= read -r -d '' file; do
    relative=${file#"$package_dir/"}
    remainder=${relative#evidence/}
    case $remainder in
        */*) ;;
        *) die "evidence file is not inside an evidence/APPROVAL-NNN/ directory: $relative" ;;
    esac
    approval_dir=${remainder%%/*}
    if ! printf '%s' "$approval_dir" | grep -Eq '^APPROVAL-[0-9]{3}$'; then
        die "evidence directory is not named APPROVAL-NNN: evidence/$approval_dir/"
    fi
    command_id=$(printf '%s' "$approval_dir" | tr '[:upper:]' '[:lower:]')
    sha256=$(sha256sum -- "$file" | cut -c1-64)
    [ "${#sha256}" -eq 64 ] || die "cannot hash $relative"

    entry=$(printf '  {\n    "path": "%s",\n    "sha256": "%s",\n    "command_id": "%s"\n  }' \
        "$(json_escape "$relative")" "$sha256" "$command_id")
    if [ -z "$entries" ]; then
        entries=$entry
    else
        entries="$entries,"$'\n'"$entry"
    fi
done < <(find "$evidence_dir" -type f -print0 | sort -z)

if [ -z "$entries" ]; then
    printf '[]\n'
else
    printf '[\n%s\n]\n' "$entries"
fi
