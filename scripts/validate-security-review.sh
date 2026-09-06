#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<'EOF'
Usage:
  validate-security-review.sh [--draft] [--baseline <prior-package-dir>] <package-dir>

Validates a review package (reviews/SR-YYYYMMDD-NNN-<short-name>/) or a
synthesis package (syntheses/SRS-YYYYMMDD-NNN-<short-name>/); the kind is
taken from the directory basename prefix. Completion mode (default) requires
Status Complete, a linted manifest, and complete records. --draft checks
structure, header keys, identifier formats, and forbidden content only.
--baseline compares append-only records against a prior copy of the package.
Prints one "ok"/"FAIL" line per check and exits 0 only with zero failures.
EOF
}

die() {
    printf 'validate-security-review: ERROR: %s\n' "$*" >&2
    exit 1
}

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) ||
    die "cannot resolve repository root"

draft=false
baseline=
while (($# > 0)); do
    case $1 in
    --draft)
        draft=true
        shift
        ;;
    --baseline)
        (($# >= 2)) || {
            usage
            exit 2
        }
        baseline=$2
        shift 2
        ;;
    --*)
        usage
        exit 2
        ;;
    *)
        break
        ;;
    esac
done
(($# == 1)) || {
    usage
    exit 2
}

[[ -d $1 ]] || die "package directory is missing: $1"
package=$(CDPATH= cd -- "$1" && pwd -P) || die "cannot resolve package directory"
case $package in
"$repository_root"/*) ;;
*) die "package escapes the repository: $1" ;;
esac
if [[ -n $baseline ]]; then
    [[ -d $baseline ]] || die "baseline package is missing: $baseline"
    baseline=$(CDPATH= cd -- "$baseline" && pwd -P) ||
        die "cannot resolve baseline directory"
fi
cd -- "$repository_root"

relative=${package#"$repository_root/"}
package_id=${package##*/}
if [[ $package_id =~ ^SR-[0-9]{8}-[0-9]{3}-[a-z0-9][a-z0-9-]{0,40}$ ]]; then
    kind=review
    id_prefix=${package_id:0:15}
elif [[ $package_id =~ ^SRS-[0-9]{8}-[0-9]{3}-[a-z0-9][a-z0-9-]{0,40}$ ]]; then
    kind=synthesis
    id_prefix=${package_id:0:16}
else
    die "package basename must match SR-YYYYMMDD-NNN-<short-name> or SRS-YYYYMMDD-NNN-<short-name>: $package_id"
fi

failures=0
ok() {
    printf 'ok   %s\n' "$*"
}
fail() {
    failures=$((failures + 1))
    printf 'FAIL %s\n' "$*"
}
assert() {
    local description=$1
    shift
    if "$@"; then
        ok "$description"
    else
        fail "$description"
    fi
}
short() {
    printf '%s' "${1#"$package/"}"
}

metadata() {
    local label=$1 file=$2
    sed -n 's/^'"$label"': `\([^`]*\)`$/\1/p' "$file" | head -n 1
}

plain_metadata() {
    local label=$1 file=$2
    sed -n "s/^$label: //p" "$file" | head -n 1
}

# Removes <!-- ... --> spans (including multi-line ones) so example records
# inside template comments are never parsed as real records.
strip_comments() {
    awk '
        {
            line = $0
            output = ""
            while (1) {
                if (in_comment) {
                    end = index(line, "-->")
                    if (end == 0) { line = ""; break }
                    line = substr(line, end + 3)
                    in_comment = 0
                } else {
                    start = index(line, "<!--")
                    if (start == 0) { output = output line; break }
                    output = output substr(line, 1, start - 1)
                    line = substr(line, start + 4)
                    in_comment = 1
                }
            }
            print output
        }
    ' "$1"
}

# Prints the data rows (after header and separator) of the table that follows
# the exact H2 heading, one per line.
table_rows() {
    local heading=$1 file=$2
    awk -v heading="$heading" '
        $0 == heading { active=1; next }
        active && /^## / { exit }
        active && /^\|/ {
            rows++
            if (rows >= 3) print
        }
    ' "$file"
}

# Prints the data rows of every table in the file (skipping the first two
# pipe lines, which are the header and separator of the single table).
all_table_rows() {
    awk '/^\|/ { rows++; if (rows >= 3) print }' "$1"
}

# Prints the trimmed, backtick-free cells of one table row, tab separated.
cells() {
    printf '%s\n' "$1" | awk -F '|' '{
        out = ""
        for (i = 2; i < NF; i++) {
            value = $i
            gsub(/^[ \t]+|[ \t]+$/, "", value)
            gsub(/`/, "", value)
            out = out (i > 2 ? "\t" : "") value
        }
        print out
    }'
}

# Flattens a JSON document to "pointer<TAB>value" lines for scalars and empty
# containers. Strings are unescaped; control characters are re-escaped so the
# output stays line oriented. Dependency-free (awk only).
json_flatten() {
    awk '
    function fatal(message) {
        printf "json: %s at offset %d\n", message, p > "/dev/stderr"
        exit 3
    }
    function skip_ws() {
        while (p <= n && index(" \t\r\n", substr(text, p, 1))) p++
    }
    function hex_value(h,   i, c, v) {
        v = 0
        for (i = 1; i <= length(h); i++) {
            c = index("0123456789abcdef", tolower(substr(h, i, 1)))
            if (c == 0) fatal("invalid unicode escape")
            v = v * 16 + (c - 1)
        }
        return v
    }
    function parse_string(   out, c, code) {
        if (substr(text, p, 1) != "\"") fatal("expected string")
        p++
        out = ""
        while (p <= n) {
            c = substr(text, p, 1)
            if (c == "\"") { p++; return out }
            if (c == "\\") {
                p++
                c = substr(text, p, 1)
                if (c == "n") out = out "\\n"
                else if (c == "t") out = out "\\t"
                else if (c == "r") out = out "\\r"
                else if (c == "b") out = out "\\b"
                else if (c == "f") out = out "\\f"
                else if (c == "u") {
                    code = hex_value(substr(text, p + 1, 4))
                    p += 4
                    if (code >= 32 && code < 127) out = out sprintf("%c", code)
                    else out = out "\\u" substr(text, p - 3, 4)
                }
                else if (c == "\"" || c == "\\" || c == "/") out = out c
                else fatal("invalid escape")
                p++
                continue
            }
            if (c == "\t") out = out "\\t"
            else if (c == "\n") out = out "\\n"
            else if (c == "\r") out = out "\\r"
            else out = out c
            p++
        }
        fatal("unterminated string")
    }
    function emit(path, value) {
        printf "%s\t%s\n", path, value
    }
    function parse_value(path,   c, start) {
        skip_ws()
        if (p > n) fatal("unexpected end of input")
        c = substr(text, p, 1)
        if (c == "{") { parse_object(path); return }
        if (c == "[") { parse_array(path); return }
        if (c == "\"") { emit(path, parse_string()); return }
        start = p
        while (p <= n && index(",]} \t\r\n", substr(text, p, 1)) == 0) p++
        if (p == start) fatal("unexpected character")
        emit(path, substr(text, start, p - start))
    }
    function parse_object(path,   key, c) {
        p++
        skip_ws()
        if (substr(text, p, 1) == "}") { p++; emit(path, "{}"); return }
        while (1) {
            skip_ws()
            if (p > n) fatal("unterminated object")
            key = parse_string()
            gsub(/~/, "~0", key)
            gsub(/\//, "~1", key)
            skip_ws()
            if (substr(text, p, 1) != ":") fatal("expected colon")
            p++
            parse_value(path "/" key)
            skip_ws()
            c = substr(text, p, 1)
            p++
            if (c == "}") return
            if (c != ",") fatal("expected comma or closing brace")
        }
    }
    function parse_array(path,   i, c) {
        p++
        skip_ws()
        if (substr(text, p, 1) == "]") { p++; emit(path, "[]"); return }
        i = 0
        while (1) {
            if (p > n) fatal("unterminated array")
            parse_value(path "/" i)
            i++
            skip_ws()
            c = substr(text, p, 1)
            p++
            if (c == "]") return
            if (c != ",") fatal("expected comma or closing bracket")
        }
    }
    { text = text $0 "\n" }
    END {
        n = length(text)
        p = 1
        parse_value("")
        skip_ws()
        if (p <= n) fatal("trailing content")
    }
    ' "$1"
}

# Looks up one pointer in flattened JSON text held in a variable.
json_get() {
    local flat=$1 pointer=$2
    awk -F '\t' -v pointer="$pointer" '
        $1 == pointer { print substr($0, length(pointer) + 2); found=1; exit }
    ' <<<"$flat"
}

json_count() {
    local flat=$1 prefix=$2
    awk -F '\t' -v prefix="$prefix" '
        index($1, prefix "/") == 1 {
            rest = substr($1, length(prefix) + 2)
            sub(/\/.*/, "", rest)
            if (rest ~ /^[0-9]+$/) seen[rest] = 1
        }
        END { count = 0; for (k in seen) count++; print count }
    ' <<<"$flat"
}

registered_component() {
    local requested=$1 name
    while IFS=$'\t' read -r name _rest; do
        [[ -n $name && $name != \#* ]] || continue
        [[ $name == workspace ]] && continue
        [[ $name == "$requested" ]] && return 0
    done < <("$repository_root/scripts/readonly-inspect.sh" components 2>/dev/null)
    return 1
}

if $draft; then
    mode_label=draft
else
    mode_label=complete
fi
printf '\n== %s package %s (%s) ==\n' "$kind" "$relative" "$mode_label"

# ---------------------------------------------------------------- artifacts

if [[ $kind == review ]]; then
    required_artifacts=(
        scope.md execution-approvals.md evidence-ledger.md search-log.md
        open-questions.md inaccessible-resources.md source-discoveries.md
        publication-checklist.md HANDOFF.md README.md SECURITY-REVIEW.md
        00-executive-summary.md 01-scope-methodology.md
        02-architecture-trust.md 03-findings.md 04-process-and-claims.md
        05-positive-observations.md 06-hardening-backlog.md
        APPENDIX-evidence-map.md iterations/REVIEW-ITERATION-001.md
        review-manifest.json
    )
    iteration_prefix=REVIEW-ITERATION
    iteration_label='Latest review iteration'
    expected_mode=independent-review
    expected_h1='# Security-review scope'
else
    required_artifacts=(
        scope.md synthesis.md disposition-ledger.md evidence-ledger.md
        search-log.md open-questions.md inaccessible-resources.md
        publication-checklist.md HANDOFF.md
        iterations/SYNTHESIS-ITERATION-001.md
    )
    iteration_prefix=SYNTHESIS-ITERATION
    iteration_label='Latest synthesis iteration'
    expected_mode=synthesis
    expected_h1='# Security-review synthesis scope'
fi

missing=0
for artifact in "${required_artifacts[@]}"; do
    if [[ ! -f $package/$artifact ]]; then
        fail "required package artifact is missing: $artifact"
        missing=$((missing + 1))
    fi
done
((missing > 0)) || ok "all ${#required_artifacts[@]} required artifacts are present"
[[ -f $package/scope.md ]] || die "scope.md is missing; nothing further can be validated"

# ------------------------------------------------------------ scope header

scope=$package/scope.md
if grep -Fqx -- "$expected_h1" "$scope"; then
    ok "scope.md carries the H1 $expected_h1"
else
    fail "scope.md must carry the H1 $expected_h1"
fi

if [[ $kind == review ]]; then
    expected_keys='Package ID
Title
Created
Status
Phase
Mode
Distribution
Execution
Latest review iteration'
else
    expected_keys='Package ID
Title
Created
Status
Phase
Mode
Distribution
Latest synthesis iteration'
fi
actual_keys=$(grep -oE '^(Package ID|Title|Created|Status|Phase|Mode|Distribution|Execution|Latest review iteration|Latest synthesis iteration):' "$scope" |
    sed 's/:$//')
if [[ $actual_keys == "$expected_keys" ]]; then
    ok "scope.md header keys are present in the specified order"
else
    fail "scope.md header keys must be exactly, in order: $(printf '%s' "$expected_keys" | tr '\n' ',' | sed 's/,/, /g')"
fi

scope_id=$(metadata 'Package ID' "$scope")
title=$(plain_metadata 'Title' "$scope")
created=$(plain_metadata 'Created' "$scope")
status=$(metadata 'Status' "$scope")
phase=$(metadata 'Phase' "$scope")
mode=$(metadata 'Mode' "$scope")
distribution=$(metadata 'Distribution' "$scope")
execution=$(metadata 'Execution' "$scope")
latest_iteration=$(metadata "$iteration_label" "$scope")

assert "scope Package ID equals the directory basename ($package_id)" \
    test "$scope_id" = "$package_id"
assert "scope Title is present" test -n "$title"
if [[ $created =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    ok "scope Created is an ISO date"
else
    fail "scope Created must be an ISO date: $created"
fi
case $status in
Draft | Complete | Blocked) ok "scope Status is valid ($status)" ;;
*) fail "scope Status must be Draft, Complete, or Blocked: $status" ;;
esac
case $phase in
Intake | Discovery | Evidence | Execution | Research | Findings | Review | Complete)
    ok "scope Phase is valid ($phase)" ;;
*) fail "scope Phase is invalid: $phase" ;;
esac
assert "scope Mode is $expected_mode" test "$mode" = "$expected_mode"
case $distribution in
private | internal | public-candidate) ok "scope Distribution is valid ($distribution)" ;;
*) fail "scope Distribution must be private, internal, or public-candidate: $distribution" ;;
esac
if [[ $kind == review ]]; then
    case $execution in
    static-only | execution-backed) ok "scope Execution is valid ($execution)" ;;
    *) fail "scope Execution must be static-only or execution-backed: $execution" ;;
    esac
fi
if [[ $latest_iteration =~ ^$iteration_prefix-[0-9]{3}$ ]]; then
    ok "scope $iteration_label is well formed ($latest_iteration)"
else
    fail "scope $iteration_label must match $iteration_prefix-NNN: $latest_iteration"
fi

# ------------------------------------------------- cross-file consistency

mapfile -t markdown_files < <(find "$package" -type f -name '*.md' | sort)
mapfile -t all_files < <(find "$package" -type f | sort)

mismatches=0
for file in "${markdown_files[@]}"; do
    [[ $(metadata 'Package ID' "$file") == "$package_id" ]] ||
        { fail "Package ID mismatch in $(short "$file")"; mismatches=$((mismatches + 1)); }
    [[ $(plain_metadata 'Title' "$file") == "$title" ]] ||
        { fail "Title mismatch in $(short "$file")"; mismatches=$((mismatches + 1)); }
    [[ $(plain_metadata 'Created' "$file") == "$created" ]] ||
        { fail "Created mismatch in $(short "$file")"; mismatches=$((mismatches + 1)); }
    [[ $(metadata 'Distribution' "$file") == "$distribution" ]] ||
        { fail "Distribution mismatch in $(short "$file")"; mismatches=$((mismatches + 1)); }
    file_status=$(metadata 'Status' "$file")
    case $file_status in
    Draft | Complete | Blocked) ;;
    *) fail "Status must be Draft, Complete, or Blocked in $(short "$file")"; mismatches=$((mismatches + 1)) ;;
    esac
done
((mismatches > 0)) ||
    ok "Package ID, Title, Created, Status, and Distribution agree across ${#markdown_files[@]} Markdown files"

# ---------------------------------------------------------- iterations

iteration_failures=0
if [[ $latest_iteration =~ ^$iteration_prefix-([0-9]{3})$ ]]; then
    latest_number=$((10#${BASH_REMATCH[1]}))
    for ((i = 1; i <= latest_number; i++)); do
        printf -v name '%s-%03d' "$iteration_prefix" "$i"
        if [[ ! -f $package/iterations/$name.md ]]; then
            fail "iteration file is missing: iterations/$name.md"
            iteration_failures=$((iteration_failures + 1))
        fi
    done
fi
while IFS= read -r iteration; do
    name=${iteration##*/}
    name=${name%.md}
    if [[ ! $name =~ ^$iteration_prefix-[0-9]{3}$ ]]; then
        fail "malformed iteration filename: $(short "$iteration")"
        iteration_failures=$((iteration_failures + 1))
        continue
    fi
    if ! grep -Fqx -- "# $name" "$iteration"; then
        fail "iteration heading does not match filename: $(short "$iteration")"
        iteration_failures=$((iteration_failures + 1))
    fi
    if [[ $latest_iteration =~ -([0-9]{3})$ && $name =~ -([0-9]{3})$ ]]; then
        this_number=$((10#${BASH_REMATCH[1]}))
        if ((this_number > latest_number)); then
            fail "iteration exceeds $iteration_label: $(short "$iteration")"
            iteration_failures=$((iteration_failures + 1))
        fi
    fi
done < <(find "$package/iterations" -type f -name '*.md' 2>/dev/null | sort)
((iteration_failures > 0)) ||
    ok "iteration files exist through $latest_iteration with matching headings"

# ------------------------------------------------------ forbidden content

path_hits=0
for file in "${all_files[@]}"; do
    if grep -aEq '(^|[^A-Za-z0-9_])/(home|Users|root)/' "$file"; then
        fail "absolute workstation path is forbidden: $(short "$file")"
        path_hits=$((path_hits + 1))
    fi
done
((path_hits > 0)) || ok "no absolute workstation path in ${#all_files[@]} files"

token_hits=0
for file in "${markdown_files[@]}"; do
    if grep -Fq '@@' "$file"; then
        fail "unsubstituted template token found: $(short "$file")"
        token_hits=$((token_hits + 1))
    fi
done
((token_hits > 0)) || ok "no unsubstituted template token"

symlink_count=$(find "$package" -type l | wc -l)
assert "package contains no symbolic links" test "$symlink_count" -eq 0

if [[ $kind == review ]]; then
    foreign=$(grep -aohE 'SR-[0-9]{8}-[0-9]{3}' "${all_files[@]}" | sort -u |
        grep -Fvx -- "$id_prefix" || true)
    if [[ -n $foreign ]]; then
        fail "independence: foreign review package identifiers referenced: $(printf '%s' "$foreign" | tr '\n' ' ')"
    else
        ok "independence: no foreign review package identifier"
    fi
    if grep -aEq 'agent-review/[A-Za-z0-9._-]+/' "${all_files[@]}"; then
        fail "independence: target-side agent-review/<pkg>/ paths must not be referenced"
    else
        ok "independence: no target-side agent-review package reference"
    fi
fi

# ----------------------------------------------------------- table IDs

validate_table_ids() {
    local file=$1 prefix=$2 require_one=$3 label
    label=$(short "$file")
    local -a identifiers
    [[ -f $file ]] || return 0
    mapfile -t identifiers < <(
        grep -E "^\| $prefix-[0-9]{3} \|" "$file" |
            awk -F '|' '{ gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' |
            sort
    )
    if [[ $require_one == yes ]] && ! $draft && ((${#identifiers[@]} == 0)); then
        fail "$label requires at least one $prefix record"
        return 0
    fi
    if ((${#identifiers[@]} > 0)); then
        duplicate=$(printf '%s\n' "${identifiers[@]}" | uniq -d | head -n 1)
        if [[ -n $duplicate ]]; then
            fail "duplicate $prefix record in $label: $duplicate"
            return 0
        fi
    fi
    ok "$label: ${#identifiers[@]} $prefix record(s), no duplicates"
}

validate_table_ids "$package/search-log.md" SEARCH yes
validate_table_ids "$package/open-questions.md" OPEN no
validate_table_ids "$package/inaccessible-resources.md" BLOCKED no
[[ $kind == review ]] && validate_table_ids "$package/source-discoveries.md" DISC no
validate_table_ids "$package/scope.md" ACTIVITY yes
validate_table_ids "$package/HANDOFF.md" ACTIVITY yes

# ------------------------------------------------------ evidence ledger

evidence_file=$package/evidence-ledger.md
declare -a evidence_definitions=()
if [[ -f $evidence_file ]]; then
    mapfile -t evidence_definitions < <(
        grep -E "^\| $package_id-E[0-9]{4} \|" "$evidence_file" |
            awk -F '|' '{ gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2 }' | sort
    )
    duplicate=$(printf '%s\n' "${evidence_definitions[@]}" | uniq -d | head -n 1)
    if [[ -n $duplicate ]]; then
        fail "duplicate evidence definition: $duplicate"
    else
        ok "evidence ledger defines ${#evidence_definitions[@]} unique evidence ID(s)"
    fi
    if ! $draft && ((${#evidence_definitions[@]} == 0)); then
        fail "completion requires at least one evidence record"
    fi
    row_failures=0
    while IFS= read -r row; do
        IFS=$'\t' read -r e_id e_source e_locator e_revision e_kind e_statement e_fact e_recorded <<<"$(cells "$row")"
        for value in "$e_source" "$e_locator" "$e_revision" "$e_kind" "$e_statement" "$e_fact" "$e_recorded"; do
            if [[ -z $value ]]; then
                fail "evidence $e_id has an empty cell"
                row_failures=$((row_failures + 1))
                break
            fi
        done
        case $e_kind in
        'Local file' | 'Command output' | 'Public source' | 'User statement' | 'Specialist return') ;;
        *) fail "evidence $e_id has invalid Kind: $e_kind"; row_failures=$((row_failures + 1)) ;;
        esac
        case $e_fact in
        Established | Inferred | Proposed | Unknown) ;;
        *) fail "evidence $e_id has invalid Fact label: $e_fact"; row_failures=$((row_failures + 1)) ;;
        esac
    done < <(grep -E "^\| $package_id-E[0-9]{4} \|" "$evidence_file")
    ((row_failures > 0)) || ok "evidence rows have complete cells and valid Kind and Fact label"

    dangling=0
    while IFS= read -r referenced; do
        if ! printf '%s\n' "${evidence_definitions[@]}" | grep -Fqx -- "$referenced"; then
            fail "evidence reference is not defined in the ledger: $referenced"
            dangling=$((dangling + 1))
        fi
    done < <(grep -aohE "$package_id-E[0-9]{4}" "${all_files[@]}" | sort -u)
    ((dangling > 0)) || ok "every referenced $package_id-E#### evidence ID is defined"
fi

# ------------------------------------------------ human promotion record

if [[ $distribution != private ]]; then
    checklist=$package/publication-checklist.md
    if grep -Fq -- '- [ ]' "$checklist"; then
        fail "promoted distribution requires every checklist item to be checked"
    else
        ok "promoted distribution: every checklist item is checked"
    fi
    record_id=$(sed -n 's/^| Record ID | \(HUMAN-PROMOTION-[0-9][0-9][0-9]\) |$/\1/p' "$checklist")
    actor=$(sed -n 's/^| Responsible human actor | \(.*\) |$/\1/p' "$checklist")
    role=$(sed -n 's/^| Responsible human role | \(.*\) |$/\1/p' "$checklist")
    stamp=$(sed -n 's/^| UTC timestamp | \(.*\) |$/\1/p' "$checklist")
    to_distribution=$(sed -n 's/^| To distribution | \(.*\) |$/\1/p' "$checklist")
    decision=$(sed -n 's/^| Decision | \(.*\) |$/\1/p' "$checklist")
    if [[ -n $record_id && -n $actor && $actor != 'Not recorded' &&
        -n $role && $role != 'Not recorded' &&
        -n $stamp && $stamp != 'Not recorded' &&
        $to_distribution == "$distribution" && $decision == promote ]]; then
        ok "promotion record $record_id authorizes distribution $distribution"
    else
        fail "promoted distribution requires a complete HUMAN-PROMOTION-NNN record with a responsible human actor and role, a UTC timestamp, To distribution $distribution, and Decision promote"
    fi
else
    ok "distribution is private; no promotion record required"
fi

# -------------------------------------------------------- snapshot row

manifest_flat=
snapshot_component=
snapshot_commit=
if [[ $kind == review ]]; then
    mapfile -t snapshot_rows < <(table_rows '## Target snapshot' "$scope")
    if ((${#snapshot_rows[@]} != 1)); then
        fail "scope.md must have exactly one Target snapshot data row (found ${#snapshot_rows[@]})"
    else
        IFS=$'\t' read -r snapshot_component snapshot_locator snapshot_commit \
            snapshot_branch snapshot_worktree snapshot_dirty_paths snapshot_checked \
            <<<"$(cells "${snapshot_rows[0]}")"
        if $draft && [[ $snapshot_component == 'Not recorded' ]]; then
            ok "draft: target snapshot is not yet recorded"
        else
            if registered_component "$snapshot_component"; then
                ok "snapshot Component is registered ($snapshot_component)"
            else
                fail "snapshot Component is not a registered target: $snapshot_component"
            fi
            assert "snapshot Logical locator is component://$snapshot_component" \
                test "$snapshot_locator" = "component://$snapshot_component"
            if [[ $snapshot_commit =~ ^[0-9a-f]{40}$ && $snapshot_commit != 0000000000000000000000000000000000000000 ]]; then
                ok "snapshot Commit is a 40-hex commit"
            else
                fail "snapshot Commit must be a nonzero lowercase 40-hex commit: $snapshot_commit"
            fi
            if [[ $snapshot_branch == refs/heads/?* || $snapshot_branch == detached ]]; then
                ok "snapshot Branch is refs/heads/... or detached"
            else
                fail "snapshot Branch must be refs/heads/... or detached: $snapshot_branch"
            fi
            case $snapshot_worktree in
            clean)
                assert "snapshot Included dirty paths is None for a clean worktree" \
                    test "$snapshot_dirty_paths" = None
                ;;
            'dirty (approved)')
                assert "snapshot Included dirty paths are listed for an approved dirty worktree" \
                    test -n "$snapshot_dirty_paths" -a "$snapshot_dirty_paths" != None
                ;;
            *) fail "snapshot Worktree state must be clean or dirty (approved): $snapshot_worktree" ;;
            esac
            assert "snapshot Checked is recorded" \
                test -n "$snapshot_checked" -a "$snapshot_checked" != 'Not recorded'
        fi
    fi

    # ----------------------------------------------------------- manifest

    manifest=$package/review-manifest.json
    if [[ -f $manifest ]]; then
        if $draft; then
            ok "draft: manifest lint skipped"
        else
            linter=$repository_root/scripts/lint-review-manifest.sh
            if [[ ! -x $linter ]]; then
                fail "manifest lint helper is missing or not executable: scripts/lint-review-manifest.sh"
            elif ! command -v node >/dev/null 2>&1; then
                fail "manifest lint requires node, which is not in PATH"
            elif lint_output=$("$linter" "$manifest" 2>&1); then
                ok "manifest lint passed: ${lint_output##*$'\n'}"
            else
                fail "manifest lint failed: $lint_output"
            fi
        fi
        if manifest_flat=$(json_flatten "$manifest" 2>/dev/null); then
            manifest_id=$(json_get "$manifest_flat" /package/id)
            manifest_component=$(json_get "$manifest_flat" /source/component)
            manifest_locator=$(json_get "$manifest_flat" /source/locator)
            manifest_commit=$(json_get "$manifest_flat" /source/commit)
            manifest_branch=$(json_get "$manifest_flat" /source/branch)
            manifest_detached=$(json_get "$manifest_flat" /source/detached)
            manifest_dirty=$(json_get "$manifest_flat" /source/dirty)
            manifest_classification=$(json_get "$manifest_flat" /execution/classification)
            if ! $draft; then
                assert "manifest package.id equals the package directory" \
                    test "$manifest_id" = "$package_id"
                assert "manifest source.component equals the snapshot Component" \
                    test "$manifest_component" = "$snapshot_component"
                assert "manifest source.locator equals the snapshot Logical locator" \
                    test "$manifest_locator" = "$snapshot_locator"
                assert "manifest source.commit equals the snapshot Commit" \
                    test "$manifest_commit" = "$snapshot_commit"
                if [[ $snapshot_branch == detached ]]; then
                    assert "manifest source.detached is true and branch null for a detached snapshot" \
                        test "$manifest_detached" = true -a "$manifest_branch" = null
                else
                    assert "manifest source.branch equals the snapshot Branch" \
                        test "$manifest_detached" = false -a "$manifest_branch" = "$snapshot_branch"
                fi
                if [[ $snapshot_worktree == clean ]]; then
                    assert "manifest source.dirty is false for a clean snapshot" \
                        test "$manifest_dirty" = false
                else
                    assert "manifest source.dirty is true for an approved dirty snapshot" \
                        test "$manifest_dirty" = true
                fi
                assert "manifest execution.classification equals scope Execution ($execution)" \
                    test "$manifest_classification" = "$execution"
            fi
        else
            fail "manifest is not parseable JSON: review-manifest.json"
            manifest_flat=
        fi
    fi

    # ---------------------------------------------------------- approvals

    approvals_file=$package/execution-approvals.md
    if [[ -f $approvals_file ]]; then
        stripped_approvals=$(strip_comments "$approvals_file")
        approvals_tsv=$(printf '%s\n' "$stripped_approvals" | awk '
            function finish() {
                if (id == "") return
                printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                    id, status, command, wd, tool, version, commit,
                    approved_by, approved_on, quoted, evdir, missing
                id = ""
            }
            function field(prefix, value) {
                if (index($0, prefix) == 1) {
                    value = substr($0, length(prefix) + 1)
                    return value
                }
                return "\001"
            }
            function ticked(prefix,   value) {
                value = field(prefix "`", "")
                if (value == "\001") return "\001"
                if (substr(value, length(value), 1) != "`") return "\001"
                value = substr(value, 1, length(value) - 1)
                if (index(value, "`") > 0) return "\001"
                return value
            }
            /^### APPROVAL-[0-9][0-9][0-9]$/ {
                finish()
                id = $2
                status = command = wd = tool = version = commit = ""
                approved_by = approved_on = quoted = evdir = ""
                missing = ""
                seen = 0
                next
            }
            id != "" && /^- Status: / { v = ticked("- Status: "); if (v != "\001") status = v; else missing = missing "Status,"; next }
            id != "" && /^- Command: / { v = ticked("- Command: "); if (v != "\001") command = v; else missing = missing "Command,"; next }
            id != "" && /^- Working directory: / { v = ticked("- Working directory: "); if (v != "\001") wd = v; else missing = missing "Working directory,"; next }
            id != "" && /^- Tool ID: / { v = ticked("- Tool ID: "); if (v != "\001") tool = v; else missing = missing "Tool ID,"; next }
            id != "" && /^- Tool version: / { v = ticked("- Tool version: "); if (v != "\001") version = v; else missing = missing "Tool version,"; next }
            id != "" && /^- Expected target commit: / { v = ticked("- Expected target commit: "); if (v != "\001") commit = v; else missing = missing "Expected target commit,"; next }
            id != "" && /^- Approved by: / { approved_by = substr($0, 15); next }
            id != "" && /^- Approved on: / { v = ticked("- Approved on: "); if (v != "\001") approved_on = v; else missing = missing "Approved on,"; next }
            id != "" && /^- Quoted approval: "/ { quoted = substr($0, 21); next }
            id != "" && /^- Evidence directory: / { v = ticked("- Evidence directory: "); if (v != "\001") evdir = v; else missing = missing "Evidence directory,"; next }
            END { finish() }
        ')
        approval_count=0
        executed_count=0
        declare -A approval_status=() approval_command=() approval_wd=() approval_tool=()
        declare -A approval_version=() approval_commit=()
        approval_failures=0
        while IFS=$'\t' read -r a_id a_status a_command a_wd a_tool a_version a_commit \
            a_by a_on a_quoted a_evdir a_missing; do
            [[ -n $a_id ]] || continue
            approval_count=$((approval_count + 1))
            if [[ -n ${approval_status[$a_id]+x} ]]; then
                fail "duplicate approval record: $a_id"
                approval_failures=$((approval_failures + 1))
                continue
            fi
            approval_status[$a_id]=$a_status
            approval_command[$a_id]=$a_command
            approval_wd[$a_id]=$a_wd
            approval_tool[$a_id]=$a_tool
            approval_version[$a_id]=$a_version
            approval_commit[$a_id]=$a_commit
            record_ok=true
            [[ -n $a_missing ]] && { fail "$a_id has malformed backticked field(s): ${a_missing%,}"; record_ok=false; }
            for pair in "Status:$a_status" "Command:$a_command" "Working directory:$a_wd" \
                "Tool ID:$a_tool" "Tool version:$a_version" "Expected target commit:$a_commit" \
                "Approved by:$a_by" "Approved on:$a_on" "Quoted approval:$a_quoted" \
                "Evidence directory:$a_evdir"; do
                if [[ -z ${pair#*:} ]]; then
                    fail "$a_id is missing ${pair%%:*}"
                    record_ok=false
                fi
            done
            case $a_status in
            approved | executed | withdrawn) ;;
            *) fail "$a_id has invalid Status: $a_status"; record_ok=false ;;
            esac
            [[ $a_wd =~ ^component://[a-z0-9][a-z0-9._-]{0,127}(/[^[:space:]]+)?$ ]] ||
                { fail "$a_id Working directory must be component://<name>[/<subpath>]: $a_wd"; record_ok=false; }
            [[ $a_tool =~ ^[a-z0-9][a-z0-9._-]{0,127}$ ]] ||
                { fail "$a_id Tool ID must be a lowercase safe identifier: $a_tool"; record_ok=false; }
            [[ $a_commit =~ ^[0-9a-f]{40}$ ]] ||
                { fail "$a_id Expected target commit must be 40 hex: $a_commit"; record_ok=false; }
            [[ $a_on =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
                { fail "$a_id Approved on must be UTC ISO-8601 (YYYY-MM-DDTHH:MM:SSZ): $a_on"; record_ok=false; }
            [[ $a_quoted == *\" ]] ||
                { fail "$a_id Quoted approval must be a quoted string"; record_ok=false; }
            [[ $a_evdir == "evidence/$a_id/" ]] ||
                { fail "$a_id Evidence directory must be evidence/$a_id/: $a_evdir"; record_ok=false; }
            if [[ $a_status == executed ]]; then
                executed_count=$((executed_count + 1))
                for evidence_name in stdout.log stderr.log exit-result.json run-record.json; do
                    if [[ ! -f $package/evidence/$a_id/$evidence_name ]]; then
                        fail "$a_id is executed but evidence/$a_id/$evidence_name is missing"
                        record_ok=false
                    fi
                done
                if ! $draft && [[ -n $manifest_flat ]]; then
                    [[ $a_commit == "$manifest_commit" ]] ||
                        { fail "$a_id Expected target commit differs from manifest source.commit"; record_ok=false; }
                fi
            fi
            $record_ok && ok "$a_id record is well formed ($a_status)" ||
                approval_failures=$((approval_failures + 1))
        done <<<"$approvals_tsv"

        if ((approval_count == 0)); then
            if printf '%s\n' "$stripped_approvals" | grep -Fqx 'No approvals recorded.'; then
                ok "execution-approvals.md states: No approvals recorded."
            else
                fail "execution-approvals.md must state 'No approvals recorded.' when it has no APPROVAL-NNN record"
            fi
        elif printf '%s\n' "$stripped_approvals" | grep -Fqx 'No approvals recorded.'; then
            fail "execution-approvals.md has APPROVAL-NNN records but still states 'No approvals recorded.'"
        fi

        if [[ $execution == static-only ]]; then
            assert "static-only package has no executed approval record" \
                test "$executed_count" -eq 0
        elif ! $draft; then
            assert "execution-backed package has at least one executed approval record" \
                test "$executed_count" -ge 1
        fi

        if [[ -n $manifest_flat ]]; then
            command_count=$(json_count "$manifest_flat" /execution/commands_attempted)
            declare -A manifest_approvals=()
            cross_failures=0
            for ((i = 0; i < command_count; i++)); do
                base=/execution/commands_attempted/$i
                m_approval=$(json_get "$manifest_flat" "$base/approval_id")
                m_command=$(json_get "$manifest_flat" "$base/command")
                m_wd=$(json_get "$manifest_flat" "$base/working_directory")
                m_tool=$(json_get "$manifest_flat" "$base/tool_id")
                manifest_approvals[$m_approval]=1
                if [[ -z ${approval_status[$m_approval]+x} ]]; then
                    fail "manifest command $m_approval has no APPROVAL record"
                    cross_failures=$((cross_failures + 1))
                    continue
                fi
                [[ ${approval_status[$m_approval]} == executed ]] ||
                    { fail "manifest command $m_approval requires Status executed (found ${approval_status[$m_approval]})"; cross_failures=$((cross_failures + 1)); }
                [[ ${approval_command[$m_approval]} == "$m_command" ]] ||
                    { fail "$m_approval command text differs between the approval record and the manifest"; cross_failures=$((cross_failures + 1)); }
                [[ ${approval_wd[$m_approval]} == "$m_wd" ]] ||
                    { fail "$m_approval working directory differs between the approval record and the manifest"; cross_failures=$((cross_failures + 1)); }
                [[ ${approval_tool[$m_approval]} == "$m_tool" ]] ||
                    { fail "$m_approval tool ID differs between the approval record and the manifest"; cross_failures=$((cross_failures + 1)); }
                tool_count=$(json_count "$manifest_flat" /execution/tool_versions)
                for ((t = 0; t < tool_count; t++)); do
                    if [[ $(json_get "$manifest_flat" "/execution/tool_versions/$t/id") == "$m_tool" ]]; then
                        m_version=$(json_get "$manifest_flat" "/execution/tool_versions/$t/version")
                        [[ ${approval_version[$m_approval]} == "$m_version" ]] ||
                            { fail "$m_approval tool version differs between the approval record and the manifest"; cross_failures=$((cross_failures + 1)); }
                    fi
                done
            done
            for a_id in "${!approval_status[@]}"; do
                if [[ ${approval_status[$a_id]} == executed && -z ${manifest_approvals[$a_id]+x} ]]; then
                    fail "$a_id is executed but has no manifest commands_attempted entry"
                    cross_failures=$((cross_failures + 1))
                elif [[ ${approval_status[$a_id]} != executed && -n ${manifest_approvals[$a_id]+x} ]]; then
                    fail "$a_id is ${approval_status[$a_id]} but appears in manifest commands_attempted"
                    cross_failures=$((cross_failures + 1))
                fi
            done
            ((cross_failures > 0)) ||
                ok "approval records and manifest commands_attempted agree ($command_count command(s))"

            # Every retained file is listed with a matching hash, and vice versa.
            evidence_failures=0
            if [[ -d $package/evidence ]]; then
                retained_count=$(json_count "$manifest_flat" /execution/retained_evidence)
                declare -A listed_hash=()
                for ((i = 0; i < retained_count; i++)); do
                    r_path=$(json_get "$manifest_flat" "/execution/retained_evidence/$i/path")
                    r_hash=$(json_get "$manifest_flat" "/execution/retained_evidence/$i/sha256")
                    listed_hash[$r_path]=$r_hash
                done
                while IFS= read -r file; do
                    rel_path=${file#"$package/"}
                    approval_dir=${rel_path#evidence/}
                    approval_dir=${approval_dir%%/*}
                    if [[ -z ${approval_status[$approval_dir]+x} ]]; then
                        fail "evidence directory has no approval record: evidence/$approval_dir/"
                        evidence_failures=$((evidence_failures + 1))
                    fi
                    if [[ -z ${listed_hash[$rel_path]+x} ]]; then
                        if ! $draft; then
                            fail "retained evidence file is not listed in the manifest: $rel_path"
                            evidence_failures=$((evidence_failures + 1))
                        fi
                    else
                        actual=$(sha256sum -- "$file")
                        actual=${actual%% *}
                        if [[ $actual != "${listed_hash[$rel_path]}" ]]; then
                            fail "retained evidence hash mismatch: $rel_path"
                            evidence_failures=$((evidence_failures + 1))
                        fi
                    fi
                done < <(find "$package/evidence" -type f | sort)
                ((evidence_failures > 0)) ||
                    ok "every retained evidence file is listed in the manifest with a matching sha256"
            fi
        fi
        ((approval_failures > 0)) || ((approval_count == 0)) ||
            ok "$approval_count approval record(s) parsed"
    fi

    # ----------------------------------------------------------- findings

    findings_file=$package/03-findings.md
    if [[ -f $findings_file ]]; then
        stripped_findings=$(strip_comments "$findings_file")
        mapfile -t finding_definitions < <(
            printf '%s\n' "$stripped_findings" |
                grep -E '^### FINDING-[0-9]{3}: ' |
                sed -E 's/^### (FINDING-[0-9]{3}):.*/\1/' | sort
        )
        duplicate=$(printf '%s\n' "${finding_definitions[@]}" | uniq -d | head -n 1)
        if [[ -n $duplicate ]]; then
            fail "duplicate finding definition: $duplicate"
        else
            ok "03-findings.md defines ${#finding_definitions[@]} unique finding(s)"
        fi
        if grep -Fqx '## Findings' "$findings_file"; then
            ok "03-findings.md has the ## Findings section"
        else
            fail "03-findings.md must have a ## Findings section"
        fi
        if ! $draft; then
            has_none=false
            printf '%s\n' "$stripped_findings" | grep -Fqx 'No findings recorded.' && has_none=true
            if ((${#finding_definitions[@]} == 0)); then
                if $has_none; then
                    ok "no findings: 03-findings.md states 'No findings recorded.'"
                else
                    fail "a package without findings must state 'No findings recorded.'"
                fi
            elif $has_none; then
                fail "03-findings.md has findings but still states 'No findings recorded.'"
            fi
            finding_output=$(printf '%s\n' "$stripped_findings" | awk -v package_id="$package_id" '
            function report(message) {
                printf "%s %s\n", id, message
                failed = 1
            }
            function finish(   i) {
                if (id == "") return
                expected = "Severity Confidence Fact_label Affected_paths Evidence Impact Recommendation Alternatives_and_counter-evidence Limitations"
                if (order != expected) report("must have exactly the specified bullet keys in order (found: " order ")")
                if (severity !~ /^`(Critical|High|Medium|Low|Informational)`$/) report("has invalid Severity: " severity)
                if (confidence !~ /^`(High|Medium|Low)`$/) report("has invalid Confidence: " confidence)
                if (fact !~ /^`(Established|Inferred|Proposed|Unknown)`$/) report("has invalid Fact label: " fact)
                if (affected != "`None`" && affected !~ /component:\/\/.* at `[0-9a-f]{40}`/) report("Affected paths must be `None` or component://<name>/<path> at `<40hex>`")
                if (evidence !~ ("`" package_id "-E[0-9][0-9][0-9][0-9]`")) report("Evidence must cite at least one `" package_id "-E####` ID")
                if (impact == "" || recommendation == "" || alternatives == "" || limitations == "") report("has an empty Impact, Recommendation, Alternatives and counter-evidence, or Limitations")
                count++
                id = ""
            }
            /^### FINDING-[0-9][0-9][0-9]: / {
                finish()
                id = $2
                sub(/:$/, "", id)
                order = ""
                severity = confidence = fact = affected = evidence = impact = ""
                recommendation = alternatives = limitations = ""
                next
            }
            id != "" && /^### / { finish(); next }
            id != "" && /^- Severity: / { order = order (order == "" ? "" : " ") "Severity"; severity = substr($0, 13); next }
            id != "" && /^- Confidence: / { order = order " Confidence"; confidence = substr($0, 15); next }
            id != "" && /^- Fact label: / { order = order " Fact_label"; fact = substr($0, 15); next }
            id != "" && /^- Affected paths: / { order = order " Affected_paths"; affected = substr($0, 19); next }
            id != "" && /^- Evidence: / { order = order " Evidence"; evidence = substr($0, 13); next }
            id != "" && /^- Impact: / { order = order " Impact"; impact = substr($0, 11); next }
            id != "" && /^- Recommendation: / { order = order " Recommendation"; recommendation = substr($0, 19); next }
            id != "" && /^- Alternatives and counter-evidence: / { order = order " Alternatives_and_counter-evidence"; alternatives = substr($0, 38); next }
            id != "" && /^- Limitations: / { order = order " Limitations"; limitations = substr($0, 16); next }
            id != "" && /^- / { report("has an unexpected bullet: " $0) }
            END { finish(); exit failed }
            ' 2>&1) && finding_status=0 || finding_status=$?
            if ((finding_status == 0)); then
                ((${#finding_definitions[@]} == 0)) ||
                    ok "every finding record is complete with valid Severity, Confidence, Fact label, Affected paths, and Evidence"
            else
                while IFS= read -r line; do
                    [[ -n $line ]] && fail "finding $line"
                done <<<"$finding_output"
            fi
            for referenced in $(grep -oE 'FINDING-[0-9]{3}' "${markdown_files[@]}" | sed 's/^.*://' | sort -u); do
                printf '%s\n' "${finding_definitions[@]}" | grep -Fqx -- "$referenced" ||
                    fail "FINDING reference is not defined in 03-findings.md: $referenced"
            done
        fi
    fi

    # ------------------------------------------------- assurance wording

    if ! $draft; then
        wording_failures=0
        for document in 01-scope-methodology.md 04-process-and-claims.md SECURITY-REVIEW.md; do
            [[ -f $package/$document ]] || continue
            if ! grep -Fq 'never grants or infers' "$package/$document"; then
                fail "$document must retain the assurance sentence 'never grants or infers'"
                wording_failures=$((wording_failures + 1))
            fi
        done
        ((wording_failures > 0)) || ok "assurance wording retained in the scope, process, and rollup documents"
    fi
fi

# -------------------------------------------------------------- synthesis

if [[ $kind == synthesis ]]; then
    mapfile -t input_rows < <(table_rows '## Input packages' "$scope")
    declare -A input_location=() input_commit=()
    declare -a input_ids=()
    distinct_commits=()
    input_failures=0
    for row in "${input_rows[@]}"; do
        IFS=$'\t' read -r in_id in_location in_commit in_status <<<"$(cells "$row")"
        if $draft && [[ $in_id == None ]]; then
            continue
        fi
        if [[ ! $in_id =~ ^SR-[0-9]{8}-[0-9]{3}-[a-z0-9][a-z0-9-]{0,40}$ ]]; then
            fail "input Package ID is malformed: $in_id"
            input_failures=$((input_failures + 1))
            continue
        fi
        input_ids+=("$in_id")
        in_location=${in_location%/}
        if [[ $in_location == /* || $in_location == *..* ]]; then
            fail "input Location must be a repository-relative path without traversal: $in_location"
            input_failures=$((input_failures + 1))
            continue
        fi
        input_location[$in_id]=$in_location
        input_commit[$in_id]=$in_commit
        if [[ ! -d $repository_root/$in_location ]]; then
            fail "input package is missing: $in_location"
            input_failures=$((input_failures + 1))
            continue
        fi
        [[ ${in_location##*/} == "$in_id" ]] ||
            { fail "input Location basename must equal the Package ID: $in_location"; input_failures=$((input_failures + 1)); }
        in_scope=$repository_root/$in_location/scope.md
        [[ $(metadata 'Package ID' "$in_scope" 2>/dev/null) == "$in_id" ]] ||
            { fail "input package scope.md does not declare Package ID $in_id"; input_failures=$((input_failures + 1)); }
        if ! $draft; then
            [[ $(metadata 'Status' "$in_scope" 2>/dev/null) == Complete ]] ||
                { fail "input package must have Status Complete: $in_id"; input_failures=$((input_failures + 1)); }
            [[ $in_status == Complete ]] ||
                { fail "input row Status must be Complete: $in_id"; input_failures=$((input_failures + 1)); }
            in_manifest=$repository_root/$in_location/review-manifest.json
            if [[ -f $in_manifest ]] && in_flat=$(json_flatten "$in_manifest" 2>/dev/null); then
                actual_commit=$(json_get "$in_flat" /source/commit)
                [[ $actual_commit == "$in_commit" ]] ||
                    { fail "input Target commit differs from the input manifest source.commit: $in_id"; input_failures=$((input_failures + 1)); }
            else
                fail "input package manifest is missing or unparseable: $in_id"
                input_failures=$((input_failures + 1))
            fi
        fi
        [[ $in_commit =~ ^[0-9a-f]{40}$ ]] ||
            { fail "input Target commit must be 40 hex: $in_id"; input_failures=$((input_failures + 1)); }
        distinct_commits+=("$in_commit")
    done
    if ! $draft && ((${#input_ids[@]} == 0)); then
        fail "completion requires at least one input package"
    fi
    ((input_failures > 0)) || ok "${#input_ids[@]} input package(s) resolved and consistent"
    if ((${#distinct_commits[@]} > 0)); then
        distinct_count=$(printf '%s\n' "${distinct_commits[@]}" | sort -u | wc -l)
        if ((distinct_count > 1)); then
            if grep -Fqx '## Commit correspondence' "$package/synthesis.md"; then
                ok "differing input commits are covered by a ## Commit correspondence section"
            else
                fail "inputs at differing commits require a ## Commit correspondence section in synthesis.md"
            fi
        fi
    fi

    synthesis_file=$package/synthesis.md
    ledger_file=$package/disposition-ledger.md
    disposition_vocabulary='^(Confirmed|Partially confirmed|Recommendation|Already addressed|Rejected-unsupported|Fixed-scope non-goal)$'
    declare -A action_defined=()
    if [[ -f $synthesis_file ]]; then
        if grep -Fqx '## Canonical actions' "$synthesis_file"; then
            ok "synthesis.md has the ## Canonical actions table"
        else
            fail "synthesis.md must have a ## Canonical actions section"
        fi
        action_failures=0
        while IFS= read -r row; do
            IFS=$'\t' read -r c_action c_priority c_title c_disposition c_dependency c_checkpoint <<<"$(cells "$row")"
            [[ $c_action == None ]] && continue
            if [[ ! $c_action =~ ^REV-P([0-3])-[0-9]{2}$ ]]; then
                fail "canonical action ID is malformed: $c_action"
                action_failures=$((action_failures + 1))
                continue
            fi
            action_priority=P${BASH_REMATCH[1]}
            if [[ -n ${action_defined[$c_action]+x} ]]; then
                fail "duplicate canonical action: $c_action"
                action_failures=$((action_failures + 1))
            fi
            action_defined[$c_action]=1
            [[ $c_priority == "$action_priority" ]] ||
                { fail "$c_action Priority must be $action_priority: $c_priority"; action_failures=$((action_failures + 1)); }
            [[ $c_disposition =~ $disposition_vocabulary ]] ||
                { fail "$c_action has invalid Disposition: $c_disposition"; action_failures=$((action_failures + 1)); }
            [[ -n $c_title && -n $c_dependency && -n $c_checkpoint ]] ||
                { fail "$c_action has an empty Title, Principal dependency, or Owner checkpoint"; action_failures=$((action_failures + 1)); }
        done < <(table_rows '## Canonical actions' "$synthesis_file")
        ((action_failures > 0)) || ok "${#action_defined[@]} canonical action(s) well formed"
        if ! $draft && ((${#action_defined[@]} == 0)); then
            fail "completion requires at least one canonical action"
        fi
    fi

    if [[ -f $ledger_file ]]; then
        ledger_failures=0
        ledger_rows=0
        declare -A dispositioned=()
        while IFS= read -r row; do
            IFS=$'\t' read -r d_finding d_package d_disposition d_action d_rationale <<<"$(cells "$row")"
            [[ $d_finding == None ]] && continue
            ledger_rows=$((ledger_rows + 1))
            [[ $d_finding =~ ^FINDING-[0-9]{3}$ ]] ||
                { fail "disposition Source finding is malformed: $d_finding"; ledger_failures=$((ledger_failures + 1)); }
            if [[ -z ${input_location[$d_package]+x} ]]; then
                fail "disposition row names a package that is not an input: $d_package"
                ledger_failures=$((ledger_failures + 1))
            fi
            dispositioned["$d_package $d_finding"]=1
            [[ $d_disposition =~ $disposition_vocabulary ]] ||
                { fail "disposition of $d_package $d_finding is invalid: $d_disposition"; ledger_failures=$((ledger_failures + 1)); }
            if [[ $d_action != None ]]; then
                [[ -n ${action_defined[$d_action]+x} ]] ||
                    { fail "disposition of $d_package $d_finding names an undefined canonical action: $d_action"; ledger_failures=$((ledger_failures + 1)); }
            fi
            [[ -n $d_rationale ]] ||
                { fail "disposition of $d_package $d_finding has no Rationale"; ledger_failures=$((ledger_failures + 1)); }
        done < <(all_table_rows "$ledger_file")
        ((ledger_failures > 0)) || ok "$ledger_rows disposition row(s) well formed"
        if ! $draft; then
            ((ledger_rows > 0)) || fail "completion requires at least one disposition row"
            coverage_failures=0
            for in_id in "${input_ids[@]}"; do
                in_findings=$repository_root/${input_location[$in_id]}/03-findings.md
                [[ -f $in_findings ]] || continue
                while IFS= read -r source_finding; do
                    [[ -n ${dispositioned["$in_id $source_finding"]+x} ]] ||
                        { fail "source finding has no disposition row: $in_id $source_finding"; coverage_failures=$((coverage_failures + 1)); }
                done < <(strip_comments "$in_findings" | grep -oE '^### FINDING-[0-9]{3}:' | sed -E 's/^### (FINDING-[0-9]{3}):/\1/')
            done
            ((coverage_failures > 0)) || ok "every source finding of every input package has a disposition row"
        fi
    fi

    if grep -Eiq '(^|[^a-z-])implemented([^a-z]|$)' "$synthesis_file" "$ledger_file" 2>/dev/null; then
        fail "a synthesis never records anything as implemented (synthesis.md, disposition-ledger.md)"
    else
        ok "synthesis records dispositions, not owner-side completion"
    fi

    # SR evidence cited by the synthesis must be defined in an input ledger.
    sr_dangling=0
    while IFS= read -r referenced; do
        [[ -n $referenced ]] || continue
        owner=${referenced%-E[0-9][0-9][0-9][0-9]}
        if [[ -z ${input_location[$owner]+x} ]]; then
            fail "evidence reference belongs to a package that is not an input: $referenced"
            sr_dangling=$((sr_dangling + 1))
        elif ! grep -Eq "^\| $referenced \|" "$repository_root/${input_location[$owner]}/evidence-ledger.md" 2>/dev/null; then
            fail "evidence reference is not defined in the input ledger: $referenced"
            sr_dangling=$((sr_dangling + 1))
        fi
    done < <(grep -aohE 'SR-[0-9]{8}-[0-9]{3}-[a-z0-9][a-z0-9-]{0,40}-E[0-9]{4}' "${all_files[@]}" | sort -u)
    ((sr_dangling > 0)) || ok "every cited input evidence ID is defined in its input package ledger"
fi

# --------------------------------------------------------------- baseline

if [[ -n $baseline ]]; then
    if [[ ${baseline##*/} != "$package_id" ]]; then
        fail "baseline must be a prior copy of the same package"
    else
        baseline_failures=0
        while IFS= read -r prior_iteration; do
            rel_iteration=${prior_iteration#"$baseline/"}
            if [[ ! -f $package/$rel_iteration ]]; then
                fail "append-only iteration was removed: $rel_iteration"
                baseline_failures=$((baseline_failures + 1))
            elif ! cmp -s -- "$prior_iteration" "$package/$rel_iteration"; then
                fail "append-only iteration changed: $rel_iteration"
                baseline_failures=$((baseline_failures + 1))
            fi
        done < <(find "$baseline/iterations" -type f -name '*.md' 2>/dev/null | sort)
        for rel_file in evidence-ledger.md search-log.md source-discoveries.md \
            inaccessible-resources.md scope.md HANDOFF.md disposition-ledger.md; do
            [[ -f $baseline/$rel_file && -f $package/$rel_file ]] || continue
            while IFS= read -r record; do
                [[ -n $record ]] || continue
                grep -Fqx -- "$record" "$package/$rel_file" ||
                    { fail "append-only record changed or was removed from $rel_file: ${record:0:80}"; baseline_failures=$((baseline_failures + 1)); }
            done < <(grep -E '(-E[0-9]{4}|SEARCH-[0-9]{3}|DISC-[0-9]{3}|BLOCKED-[0-9]{3}|ACTIVITY-[0-9]{3}|^\| FINDING-[0-9]{3} \|)' "$baseline/$rel_file" || true)
        done
        if [[ -f $baseline/execution-approvals.md && -f $package/execution-approvals.md ]]; then
            while IFS= read -r heading; do
                grep -Fqx -- "$heading" "$package/execution-approvals.md" ||
                    { fail "approval record was removed: $heading"; baseline_failures=$((baseline_failures + 1)); }
            done < <(grep -E '^### APPROVAL-[0-9]{3}$' "$baseline/execution-approvals.md" || true)
        fi
        ((baseline_failures > 0)) || ok "append-only iterations and records are preserved against the baseline"
    fi
fi

# ------------------------------------------------------------ completion

if ! $draft; then
    [[ $status == Complete ]] || fail "completion validation requires scope Status Complete (found $status)"
    [[ $phase == Complete ]] || fail "completion validation requires scope Phase Complete (found $phase)"
    incomplete=0
    for file in "${markdown_files[@]}"; do
        [[ $(metadata 'Status' "$file") == Complete ]] ||
            { fail "$(short "$file") must have Status Complete"; incomplete=$((incomplete + 1)); }
    done
    ((incomplete > 0)) || ok "every Markdown artifact has Status Complete"
else
    case $status in
    Draft | Complete | Blocked) ;;
    *) fail "draft validation requires Status Draft, Complete, or Blocked" ;;
    esac
fi

printf '\n'
if ((failures == 0)); then
    printf 'validate-security-review: OK: %s (%s)\n' "$relative" "$mode_label"
    exit 0
fi
printf 'validate-security-review: FAILED: %s (%s): %d failure(s)\n' "$relative" "$mode_label" "$failures" >&2
exit 1
