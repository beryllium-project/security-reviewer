#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>
#
# Run one human-approved command against a registered target component and
# retain the evidence inside the security-review package. The helper enforces
# the APPROVAL-NNN contract in contracts/REVIEW-PROVENANCE.md: it refuses to
# run anything that is not recorded, approved, and aimed at the expected
# target revision. It never writes the target; the only writes are under
# <package-dir>/evidence/APPROVAL-NNN/.

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<'EOF'
Usage:
  run-approved-command.sh <package-dir> <APPROVAL-NNN>

Reads the APPROVAL-NNN record from <package-dir>/execution-approvals.md,
verifies the target through scripts/readonly-inspect.sh, runs the approved
command once with a clean environment, and writes stdout.log, stderr.log,
exit-result.json, and run-record.json to <package-dir>/evidence/APPROVAL-NNN/.
Prints ready-to-paste commands_attempted[] and tool_versions[] fragments.
Exits 0 when the approved command ran (even if it failed) and nonzero only
for the helper's own refusals.
EOF
}

die() {
    printf 'run-approved-command: ERROR: %s\n' "$*" >&2
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

utc_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# Extract the text between the first and last backtick of a "- Key: `value`"
# record line. Commands must not contain backticks, so this is exact.
record_field() {
    local key=$1 line
    line=$(printf '%s\n' "$record" | grep -m1 -E "^- $key: " || true)
    [ -n "$line" ] || return 1
    line=${line#"- $key: "}
    case $line in
        *\`*\`*)
            line=${line#*\`}
            line=${line%\`*}
            ;;
    esac
    printf '%s' "$line"
}

if [ "$#" -ne 2 ]; then
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
inspect="$repository_root/scripts/readonly-inspect.sh"

package_dir=$1
approval_id=$2

printf '%s' "$approval_id" | grep -Eq '^APPROVAL-[0-9]{3}$' ||
    die "approval id must match APPROVAL-NNN: $approval_id"
[ -d "$package_dir" ] || die "package directory not found: $package_dir"
package_dir=$(CDPATH= cd -- "$package_dir" && pwd -P) ||
    die "cannot resolve package directory"
approvals_file="$package_dir/execution-approvals.md"
[ -f "$approvals_file" ] || die "missing execution-approvals.md in package"
scope_file="$package_dir/scope.md"

# --- 1. Parse and check the approval record -------------------------------

record=$(awk -v heading="### $approval_id" '
    $0 == heading { found = 1; next }
    found && /^### / { exit }
    found { print }
' "$approvals_file")
[ -n "$record" ] || die "no record '### $approval_id' in execution-approvals.md"

missing=""
for key in "Status" "Command" "Working directory" "Tool ID" "Tool version" \
    "Expected target commit" "Approved by" "Approved on" "Quoted approval" \
    "Evidence directory"; do
    if ! value=$(record_field "$key") || [ -z "$value" ]; then
        missing="$missing '$key'"
    fi
done
[ -z "$missing" ] || die "$approval_id is missing field(s):$missing"

status=$(record_field "Status")
command_text=$(record_field "Command")
working_directory=$(record_field "Working directory")
tool_id=$(record_field "Tool ID")
tool_version=$(record_field "Tool version")
expected_commit=$(record_field "Expected target commit")
evidence_field=$(record_field "Evidence directory")

[ "$status" = "approved" ] ||
    die "$approval_id has Status '$status'; only 'approved' records may run"
printf '%s' "$tool_id" | grep -Eq '^[a-z0-9][a-z0-9._-]{0,127}$' ||
    die "$approval_id Tool ID is not a lowercase portable identifier: $tool_id"
printf '%s' "$expected_commit" | grep -Eq '^[0-9a-f]{40}$' ||
    die "$approval_id Expected target commit is not a full lowercase 40-hex commit"
[ "$evidence_field" = "evidence/$approval_id/" ] ||
    die "$approval_id Evidence directory must be evidence/$approval_id/ (found '$evidence_field')"
case $command_text in
    *\`*) die "$approval_id Command must not contain backticks" ;;
esac

# --- 2. Resolve and verify the target --------------------------------------

case $working_directory in
    component://*) ;;
    *) die "$approval_id Working directory must be component://<name>[/<subpath>]" ;;
esac
locator_rest=${working_directory#component://}
component=${locator_rest%%/*}
subpath=""
case $locator_rest in
    */*) subpath=${locator_rest#*/} ;;
esac
printf '%s' "$component" | grep -Eq '^[a-z0-9][a-z0-9._-]{0,127}$' ||
    die "$approval_id Working directory names an invalid component: $component"
if [ -n "$subpath" ]; then
    case "/$subpath/" in
        *//* | */./* | */../* | *\\*) die "$approval_id Working directory subpath is not portable: $subpath" ;;
    esac
fi

[ -f "$inspect" ] || die "scripts/readonly-inspect.sh not found; cannot verify the target"
component_root=$("$inspect" path "$component") ||
    die "component '$component' is not registered or not present (readonly-inspect.sh path failed)"
[ -n "$component_root" ] && [ -d "$component_root" ] ||
    die "resolved path for component '$component' is not a directory"
target_dir="$component_root"
if [ -n "$subpath" ]; then
    target_dir="$component_root/$subpath"
    [ -d "$target_dir" ] || die "working directory subpath does not exist in target: $subpath"
fi

state_output=$("$inspect" state "$component") ||
    die "readonly-inspect.sh state failed for component '$component'"
observed_commit=$(printf '%s\n' "$state_output" | awk '$1 == "commit" { print $2; exit }')
observed_dirty=$(printf '%s\n' "$state_output" | awk '$1 == "dirty" { print $2; exit }')
printf '%s' "$observed_commit" | grep -Eq '^[0-9a-f]{40}$' ||
    die "could not parse a 40-hex 'commit' line from readonly-inspect.sh state"
case $observed_dirty in
    true | false) ;;
    *) die "could not parse a 'dirty true|false' line from readonly-inspect.sh state" ;;
esac
[ "$observed_commit" = "$expected_commit" ] ||
    die "target commit $observed_commit differs from Expected target commit $expected_commit; refusing to run"
if [ "$observed_dirty" = true ]; then
    [ -f "$scope_file" ] || die "target is dirty and the package has no scope.md to approve that state"
    grep -Fq 'dirty (approved)' "$scope_file" ||
        die "target worktree is dirty and scope.md does not record 'dirty (approved)'; refusing to run"
fi

# --- 3. Create the evidence directory -------------------------------------

evidence_dir="$package_dir/evidence/$approval_id"
[ ! -e "$evidence_dir" ] && [ ! -L "$evidence_dir" ] ||
    die "evidence directory already exists: evidence/$approval_id/ (never overwrite evidence)"
mkdir -p -- "$evidence_dir"

# --- 4. Run the command ----------------------------------------------------

clean_environment=(
    env -i
    "PATH=$PATH"
    "HOME=/nonexistent"
    "LC_ALL=C"
    "TERM=dumb"
)

started_utc=$(utc_now)
exit_result=""
if ! bash_executable=$(command -v bash) || [ ! -x "$bash_executable" ]; then
    exit_result='{"kind":"not-started","reason":"bash executable not found"}'
elif ! env_executable=$(command -v env) || [ ! -x "$env_executable" ]; then
    exit_result='{"kind":"not-started","reason":"env executable not found"}'
elif ! (cd -- "$target_dir") 2>/dev/null; then
    exit_result="{\"kind\":\"not-started\",\"reason\":\"cannot enter working directory $(json_escape "$working_directory")\"}"
fi

if [ -z "$exit_result" ]; then
    # Background + wait keeps bash from printing job-termination notices
    # when the approved command dies from a signal.
    set +e
    (
        cd -- "$target_dir" &&
            exec "${clean_environment[@]}" "$bash_executable" -c "$command_text"
    ) </dev/null >"$evidence_dir/stdout.log" 2>"$evidence_dir/stderr.log" &
    child=$!
    wait "$child"
    run_status=$?
    set -e
    if [ "$run_status" -gt 128 ] && [ "$run_status" -le 192 ]; then
        signal_number=$((run_status - 128))
        if signal_name=$(kill -l "$signal_number" 2>/dev/null) && [ -n "$signal_name" ]; then
            signal_name=${signal_name#SIG}
            exit_result="{\"kind\":\"signaled\",\"signal\":\"SIG$signal_name\"}"
        fi
    fi
    if [ -z "$exit_result" ]; then
        exit_result="{\"kind\":\"exited\",\"code\":$run_status}"
    fi
else
    : >"$evidence_dir/stdout.log"
    : >"$evidence_dir/stderr.log"
fi
finished_utc=$(utc_now)

printf '%s\n' "$exit_result" >"$evidence_dir/exit-result.json"

# Post-run worktree state, so a command that dirtied the target is visible.
post_run_paths="[]"
if command -v git >/dev/null 2>&1; then
    porcelain=$("${clean_environment[@]}" \
        GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0 GIT_CONFIG_NOSYSTEM=1 GIT_PAGER=cat \
        git -C "$component_root" -c core.hooksPath=/dev/null -c core.fsmonitor=false \
        status --porcelain 2>/dev/null || true)
    if [ -n "$porcelain" ]; then
        post_run_paths="["
        first=true
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            if [ "$first" = true ]; then
                first=false
            else
                post_run_paths="$post_run_paths,"
            fi
            post_run_paths="$post_run_paths\"$(json_escape "$line")\""
        done <<<"$porcelain"
        post_run_paths="$post_run_paths]"
    fi
fi

printf '{\n  "approval_id": "%s",\n  "command": "%s",\n  "working_directory": "%s",\n  "observed_commit": "%s",\n  "observed_dirty": %s,\n  "started_utc": "%s",\n  "finished_utc": "%s",\n  "post_run_dirty_paths": %s\n}\n' \
    "$approval_id" \
    "$(json_escape "$command_text")" \
    "$(json_escape "$working_directory")" \
    "$observed_commit" \
    "$observed_dirty" \
    "$started_utc" \
    "$finished_utc" \
    "$post_run_paths" \
    >"$evidence_dir/run-record.json"

# --- 5. Report -------------------------------------------------------------

command_id=$(printf '%s' "$approval_id" | tr '[:upper:]' '[:lower:]')

printf 'run-approved-command: %s ran in %s; evidence in evidence/%s/\n\n' \
    "$approval_id" "$working_directory" "$approval_id"
printf 'commands_attempted[] entry:\n'
printf '{\n  "id": "%s",\n  "approval_id": "%s",\n  "command": "%s",\n  "working_directory": "%s",\n  "tool_id": "%s",\n  "exit_result": %s\n}\n\n' \
    "$command_id" \
    "$approval_id" \
    "$(json_escape "$command_text")" \
    "$(json_escape "$working_directory")" \
    "$tool_id" \
    "$exit_result"
printf 'tool_versions[] entry:\n'
printf '{\n  "id": "%s",\n  "version": "%s"\n}\n\n' \
    "$tool_id" "$(json_escape "$tool_version")"
printf 'Next steps:\n'
printf '  1. Set "Status: `executed`" on %s in execution-approvals.md.\n' "$approval_id"
printf '  2. Add the entries above to review-manifest.json (classification execution-backed, static_only_reason null).\n'
printf '  3. Run scripts/hash-evidence.sh %s and paste the retained_evidence[] array.\n' "$package_dir"
if [ "$tool_version" = "unknown" ]; then
    printf '  4. Tool version is unknown: add a qualifications[] entry for /execution/tool_versions.\n'
fi
if [ "$post_run_paths" != "[]" ]; then
    printf 'WARNING: the target worktree is dirty after the run; see post_run_dirty_paths in run-record.json. The helper never cleans a target.\n'
fi
