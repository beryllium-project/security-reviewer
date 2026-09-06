#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<'EOF'
Usage:
  new-synthesis.sh <short-name> <title>

Allocates syntheses/SRS-YYYYMMDD-NNN-<short-name>/ (UTC date; NNN is the next
free sequence for that date), instantiates every synthesis-package template,
and prints the package path relative to the repository root. An existing
package directory is never overwritten.
EOF
}

die() {
    printf 'new-synthesis: ERROR: %s\n' "$*" >&2
    exit 1
}

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) ||
    die "cannot resolve repository root"
cd -- "$repository_root"

(($# == 2)) || {
    usage
    exit 2
}

slug=$1
title=$2

[[ $slug =~ ^[a-z0-9][a-z0-9-]{0,40}$ ]] ||
    die "short name must match ^[a-z0-9][a-z0-9-]{0,40}\$"
[[ -n $title && $title =~ ^[[:print:]]+$ && $title != *'@@'* &&
    $title != *'|'* ]] ||
    die "title must be printable text without template tokens or table delimiters"

date_tag=$(date -u +%Y%m%d)
created=$(date -u +%Y-%m-%d)
mkdir -p -- syntheses

sequence=1
while ((sequence <= 999)); do
    printf -v sequence_text '%03d' "$sequence"
    prefix=SRS-$date_tag-$sequence_text
    shopt -s nullglob
    existing_packages=(syntheses/"$prefix"-*)
    shopt -u nullglob
    ((${#existing_packages[@]} == 0)) && break
    sequence=$((sequence + 1))
done
((sequence <= 999)) || die "no package identifier remains for UTC date $date_tag"

package_id=$prefix-$slug
package_dir=syntheses/$package_id
[[ ! -e $package_dir ]] || die "package directory already exists: $package_dir"

mkdir -- "$package_dir"
mkdir -- "$package_dir/iterations"

escape_replacement() {
    printf '%s' "$1" | sed 's/[\/&\\]/\\&/g'
}

escaped_id=$(escape_replacement "$package_id")
escaped_title=$(escape_replacement "$title")
escaped_created=$(escape_replacement "$created")

instantiate() {
    local source=$1 destination=$2
    [[ -f $source ]] || die "missing template: $source"
    [[ ! -e $destination ]] || die "refusing to overwrite: $destination"
    sed \
        -e "s/@@PACKAGE_ID@@/$escaped_id/g" \
        -e "s/@@TITLE@@/$escaped_title/g" \
        -e "s/@@CREATED@@/$escaped_created/g" \
        "$source" >"$destination"
}

instantiate templates/synthesis-scope.md "$package_dir/scope.md"
instantiate templates/synthesis.md "$package_dir/synthesis.md"
instantiate templates/disposition-ledger.md "$package_dir/disposition-ledger.md"
for artifact in evidence-ledger search-log open-questions \
    inaccessible-resources publication-checklist HANDOFF; do
    instantiate "templates/$artifact.md" "$package_dir/$artifact.md"
done
instantiate templates/synthesis-iteration.md \
    "$package_dir/iterations/SYNTHESIS-ITERATION-001.md"

printf '%s\n' "$package_dir"
