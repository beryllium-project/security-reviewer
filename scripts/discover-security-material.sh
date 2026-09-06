#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<'EOF'
Usage:
  discover-security-material.sh component <component> <revision>
  discover-security-material.sh project

Output is a deterministic, read-only candidate inventory of security-review
material with a suggested class per candidate:

  Prior security review | Threat model | Assurance or claim boundary |
  Design input | Test or verification evidence | Release or publication gate

The classes Stale, Conflicting, and Irrelevant are assigned only by the human
during confirmation; this script never emits them. The inventory is evidence
for human confirmation, not an authoritative selection. Paths under
sources/restricted-microsoft/ are never listed.
EOF
}

die() {
    printf 'discover-security-material: ERROR: %s\n' "$*" >&2
    exit 1
}

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) ||
    die "cannot resolve repository root"
inspect=$repository_root/scripts/readonly-inspect.sh
[[ -x $inspect ]] || die "readonly inspection helper is unavailable"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/security-material.XXXXXX") ||
    die "cannot create temporary directory"
cleanup() {
    rm -rf -- "$tmpdir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

raw=$tmpdir/raw.tsv
: >"$raw"

classify_path() {
    local path=${1,,}
    case $path in
    *review-manifest.json | *agent-review* | *security-review* | \
        *security-audit* | *security-assessment* | reviews/* | */reviews/*)
        printf 'Prior security review'
        ;;
    *threat*model*) printf 'Threat model' ;;
    *security-and-limits* | *assurance* | *claim* | *limits* | *non-goal* | \
        *assumption* | security.md | */security.md)
        printf 'Assurance or claim boundary'
        ;;
    *publication* | *release* | *gate* | *policy-alignment* | *finalization*)
        printf 'Release or publication gate'
        ;;
    *evidence* | *verification* | *evaluation* | *cbmc* | *proof* | *test*)
        printf 'Test or verification evidence'
        ;;
    *) printf 'Design input' ;;
    esac
}

classify_match() {
    local path=${1,,} text=${2,,}
    if [[ $text =~ security[\ -]?(review|audit|assessment)|review-manifest|agent-review|cve-[0-9]{4}-|security\ advisor ]]; then
        printf 'Prior security review'
    elif [[ $text =~ threat[\ -]?model ]]; then
        printf 'Threat model'
    elif [[ $text =~ publication\ gate|release\ gate|policy\ alignment ]]; then
        printf 'Release or publication gate'
    elif [[ $text =~ verification\ evidence|test\ evidence|machine-checked|cbmc|not\ run ]]; then
        printf 'Test or verification evidence'
    elif [[ $text =~ assurance|claim[\ -]boundar|not\ formally\ verified|security[\ -]and[\ -]limits|limits?\ of\ (the\ )?(claim|evidence) ]]; then
        printf 'Assurance or claim boundary'
    elif [[ $text =~ hardening|attack\ surface|trust\ boundar|fail-closed|residual\ risk|vulnerabilit ]]; then
        printf 'Design input'
    else
        classify_path "$path"
    fi
}

logical_locator() {
    local component=$1 path=$2
    if [[ $component == workspace ]]; then
        printf 'workspace://%s' "$path"
    else
        printf 'component://%s/%s' "$component" "$path"
    fi
}

emit_component() {
    local component=$1 revision=$2 commit files matches path class line rest
    local text line_number
    commit=$("$inspect" resolve "$component" "$revision" |
        awk -F '\t' '$1 == "commit" { print $2 }')
    [[ $commit =~ ^[0-9a-fA-F]{40,64}$ ]] ||
        die "cannot resolve $component revision $revision"

    files=$tmpdir/$component.files
    matches=$tmpdir/$component.matches
    "$inspect" ls-tree "$component" "$commit" >"$files"
    "$inspect" search "$component" "$commit" >"$matches"

    while IFS= read -r path; do
        [[ -n $path ]] || continue
        case $path in
        sources/* | */sources/* | docs/html/* | */docs/html/* | \
        reviews/*/html/* | */reviews/*/html/* | node_modules/* | \
        */node_modules/* | build/* | */build/* | tests/fixtures/* | \
        */tests/fixtures/*)
            continue
            ;;
        esac
        case ${path,,} in
        *.md | *.txt | *.rst | *.adoc | *review-manifest.json) ;;
        *) continue ;;
        esac
        if [[ ${path,,} =~ (security|threat|review|assurance|claim|limits|non-goal|assumption|design|architecture|risk|attack|hardening|evidence|verification|evaluation|publication|release|gate|policy|finalization|cve|advisor) ]]; then
            class=$(classify_path "$path")
            printf '%s\t%s\t%s\t%s\tfilename\n' \
                "$component" "$commit" "$class" \
                "$(logical_locator "$component" "$path")" >>"$raw"
        fi
    done <"$files"

    while IFS= read -r line; do
        [[ -n $line ]] || continue
        line=${line#"$commit:"}
        path=${line%%:*}
        rest=${line#*:}
        [[ $rest != "$line" ]] || continue
        line_number=${rest%%:*}
        text=${rest#*:}
        [[ $path != sources/restricted-microsoft &&
            $path != sources/restricted-microsoft/* &&
            $path != */sources/restricted-microsoft/* ]] || continue
        class=$(classify_match "$path" "$text")
        printf '%s\t%s\t%s\t%s\tcontent-line-%s\n' \
            "$component" "$commit" "$class" \
            "$(logical_locator "$component" "$path")" "$line_number" >>"$raw"
    done <"$matches"
}

(($# >= 1)) || {
    usage
    exit 2
}

case $1 in
component)
    (($# == 3)) || {
        usage
        exit 2
    }
    emit_component "$2" "$3"
    ;;
project)
    (($# == 1)) || {
        usage
        exit 2
    }
    while IFS=$'\t' read -r component state _branch _head; do
        [[ -n $component && $component != \#* ]] || continue
        [[ $state != absent && $state != unresolvable ]] || continue
        emit_component "$component" HEAD
    done < <("$inspect" components)
    ;;
*)
    usage
    exit 2
    ;;
esac

printf '# security-review material candidates\n'
printf 'Candidate\tComponent\tRevision\tClass\tLogical locator\tBasis\n'
sort -u -t $'\t' -k1,1 -k2,2 -k3,3 -k4,4 -k5,5V "$raw" |
    awk -F '\t' '
        function emit() {
            if (key == "") return
            count++
            printf "CANDIDATE-%03d\t%s\t%s\t%s\t%s\t%s\n",
                count, component, revision, class, locator, basis
        }
        {
            candidate_key=$1 "\t" $2 "\t" $3 "\t" $4
            if (candidate_key != key) {
                emit()
                key=candidate_key
                component=$1
                revision=$2
                class=$3
                locator=$4
                basis=$5
            }
        }
        END { emit() }
    '
