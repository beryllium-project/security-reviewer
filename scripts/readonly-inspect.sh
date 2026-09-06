#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>

set -euo pipefail
export LC_ALL=C

usage() {
    cat >&2 <<'EOF'
Usage:
  readonly-inspect.sh components
  readonly-inspect.sh path      <component>
  readonly-inspect.sh identity  <component>
  readonly-inspect.sh state     <component>
  readonly-inspect.sh resolve   <component> <revision>
  readonly-inspect.sh log       <component> <revision> [max-count] [relative-path]
  readonly-inspect.sh show      <component> <revision> <relative-path>
  readonly-inspect.sh ls-tree   <component> <revision> [relative-path]
  readonly-inspect.sh search    <component> <revision>
  readonly-inspect.sh hash-file <component> <relative-path>

Registered component names are reported by the components mode. "workspace"
means the Beryllium parent coordination repository that contains this
component. Every mode is read-only; the security-reviewer repository itself is
never a target.
EOF
}

die() {
    printf 'readonly-inspect: ERROR: %s\n' "$*" >&2
    exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) ||
    die "cannot resolve script directory"
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P) ||
    die "cannot resolve repository root"
workspace_root=$(CDPATH= cd -- "$repository_root/.." && pwd -P) ||
    die "cannot resolve workspace root"

registered_components=(
    beryllium-repo
    helium-te-poc
    formal-verification-research
    osr-claude
    provenance-review
    analysis-workbook
    threat-modeler
    project-manager
    cheri-riscv-notes-repo
    xrv-research-repo
)

clean_environment=(
    env -i
    "PATH=$PATH"
    "HOME=/nonexistent"
    "XDG_CONFIG_HOME=/nonexistent"
    "LC_ALL=C"
    "GIT_TERMINAL_PROMPT=0"
    "GIT_ASKPASS=/bin/false"
    "SSH_ASKPASS=/bin/false"
    "GIT_CONFIG_NOSYSTEM=1"
    "GIT_OPTIONAL_LOCKS=0"
    "GIT_PAGER=cat"
    "PAGER=cat"
)

safe_git_options=(
    git
    -c core.hooksPath=/dev/null
    -c core.fsmonitor=false
    -c core.attributesFile=/dev/null
    -c core.autocrlf=false
    -c core.safecrlf=false
    -c credential.helper=
    -c protocol.allow=never
    -c diff.external=
    -c diff.trustExitCode=false
    -c pager.status=false
    -c pager.log=false
    -c pager.show=false
    -c pager.diff=false
)

is_registered() {
    local requested=$1 candidate
    [[ $requested == workspace ]] && return 0
    for candidate in "${registered_components[@]}"; do
        [[ $requested == "$candidate" ]] && return 0
    done
    return 1
}

validate_revision() {
    local revision=$1
    [[ -n $revision && $revision != -* &&
        $revision =~ ^[A-Za-z0-9._/@{}^~:+-]+$ ]] ||
        die "invalid revision argument: $revision"
}

validate_path() {
    local path=$1
    [[ -n $path && $path != /* && $path != -* && $path != *\\* &&
        $path != .git && $path != .git/* &&
        $path != .. && $path != ../* && $path != */../* &&
        $path != */.. && $path != sources/restricted-microsoft &&
        $path != sources/restricted-microsoft/* &&
        $path != */sources/restricted-microsoft &&
        $path != */sources/restricted-microsoft/* &&
        $path =~ ^[[:print:]]+$ ]] ||
        die "path must be component-relative, non-restricted, and without traversal: $path"
}

validate_count() {
    local count=$1
    [[ $count =~ ^[1-9][0-9]{0,3}$ ]] ||
        die "max-count must be an integer between 1 and 9999: $count"
}

component_name=
component_dir=
component_root=
component_locator=
object_format=
component_git=()

component_path() {
    local requested=$1
    if [[ $requested == workspace ]]; then
        printf '%s' "$workspace_root"
    else
        printf '%s/%s' "$workspace_root" "$requested"
    fi
}

open_component() {
    local requested=$1 requested_path resolved root
    is_registered "$requested" || die "unregistered component: $requested"

    requested_path=$(component_path "$requested")
    if [[ $requested == workspace ]]; then
        component_locator=workspace://
    else
        component_locator=component://$requested
    fi
    [[ -e $requested_path ]] || die "component is absent: $requested"
    resolved=$(CDPATH= cd -- "$requested_path" 2>/dev/null && pwd -P) ||
        die "cannot resolve component: $requested"
    [[ $resolved != "$repository_root" ]] ||
        die "the security-reviewer repository is not a review target"
    component_dir=$resolved

    component_git=(
        "${clean_environment[@]}"
        "${safe_git_options[@]}"
        -C "$resolved"
    )
    "${component_git[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
        die "not a Git work tree: $requested"
    root=$("${component_git[@]}" rev-parse --show-toplevel) ||
        die "cannot resolve Git root: $requested"
    component_root=$(CDPATH= cd -- "$root" && pwd -P) ||
        die "cannot canonicalize Git root: $requested"
    [[ $component_root =~ ^[[:print:]]+$ &&
        ! $component_root =~ [[:cntrl:]] ]] ||
        die "component path contains unsupported control characters"

    object_format=$("${component_git[@]}" rev-parse --show-object-format) ||
        die "cannot determine Git object format: $requested"
    case $object_format in
    sha1 | sha256) ;;
    *) die "unsupported Git object format: $object_format" ;;
    esac
    component_name=$requested
}

logical_file_locator() {
    local path=${1:-}
    if [[ -z $path ]]; then
        printf '%s' "$component_locator"
    elif [[ $component_name == workspace ]]; then
        printf 'workspace://%s' "$path"
    else
        printf 'component://%s/%s' "$component_name" "$path"
    fi
}

# Prints the full branch ref (refs/heads/...) or "detached".
current_branch() {
    local ref
    if ref=$("${component_git[@]}" symbolic-ref -q HEAD 2>/dev/null); then
        printf '%s' "$ref"
    else
        printf 'detached'
    fi
}

(($# >= 1)) || {
    usage
    exit 2
}

mode=$1
shift

case $mode in
components)
    (($# == 0)) || {
        usage
        exit 2
    }
    printf '# registered security-review targets\n'
    printf '# checked: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for name in workspace "${registered_components[@]}"; do
        path=$(component_path "$name")
        if [[ ! -e $path ]]; then
            printf '%s\tabsent\t-\t-\n' "$name"
            continue
        fi
        (
            open_component "$name" 2>/dev/null || exit 1
            head=$("${component_git[@]}" rev-parse HEAD 2>/dev/null || printf 'unborn')
            branch=$(current_branch)
            if [[ -n $("${component_git[@]}" status --porcelain 2>/dev/null) ]]; then
                state=dirty
            else
                state=clean
            fi
            printf '%s\t%s\t%s\t%s\n' "$name" "$state" "$branch" "$head"
        ) || printf '%s\tunresolvable\t-\t-\n' "$name"
    done
    ;;

path)
    (($# == 1)) || {
        usage
        exit 2
    }
    open_component "$1"
    printf '%s\n' "$component_dir"
    ;;

identity)
    (($# == 1)) || {
        usage
        exit 2
    }
    open_component "$1"
    printf 'logical-locator\t%s\n' "$component_locator"
    printf 'object-format\t%s\n' "$object_format"
    printf 'head\t%s\n' "$("${component_git[@]}" rev-parse HEAD)"
    printf 'branch\t%s\n' "$(current_branch)"
    printf 'checked\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ;;

state)
    (($# == 1)) || {
        usage
        exit 2
    }
    open_component "$1"
    head=$("${component_git[@]}" rev-parse --verify HEAD 2>/dev/null) ||
        die "component has no commit: $1"
    [[ $head =~ ^[0-9a-f]{40}$ ]] ||
        die "component HEAD is not a 40-hex commit (object format $object_format): $1"
    branch=$(current_branch)
    porcelain=$("${component_git[@]}" status --porcelain 2>/dev/null || true)
    printf 'commit %s\n' "$head"
    printf 'branch %s\n' "$branch"
    if [[ -n $porcelain ]]; then
        printf 'dirty true\n'
        while IFS= read -r entry; do
            [[ -n $entry ]] || continue
            printf 'dirty-path %s\n' "${entry:3}"
        done <<<"$porcelain"
    else
        printf 'dirty false\n'
    fi
    ;;

resolve)
    (($# == 2)) || {
        usage
        exit 2
    }
    open_component "$1"
    validate_revision "$2"
    commit=$("${component_git[@]}" rev-parse --verify "$2^{commit}" 2>/dev/null) ||
        die "revision does not resolve to a commit: $2"
    printf 'logical-locator\t%s\n' "$component_locator"
    printf 'revision\t%s\n' "$2"
    printf 'commit\t%s\n' "$commit"
    "${component_git[@]}" log -1 --no-color --date=iso-strict \
        --pretty=format:'date%x09%ad%nsubject%x09%s' "$commit"
    printf '\n'
    ;;

log)
    (($# >= 2 && $# <= 4)) || {
        usage
        exit 2
    }
    open_component "$1"
    validate_revision "$2"
    count=${3:-40}
    validate_count "$count"
    commit=$("${component_git[@]}" rev-parse --verify "$2^{commit}" 2>/dev/null) ||
        die "revision does not resolve to a commit: $2"
    if (($# == 4)); then
        validate_path "$4"
        "${component_git[@]}" log --no-color --no-ext-diff \
            --max-count="$count" --date=iso-strict \
            --pretty=format:'%H%x09%ad%x09%s' "$commit" -- "$4"
    else
        "${component_git[@]}" log --no-color --no-ext-diff \
            --max-count="$count" --date=iso-strict \
            --pretty=format:'%H%x09%ad%x09%s' "$commit"
    fi
    printf '\n'
    ;;

show)
    (($# == 3)) || {
        usage
        exit 2
    }
    open_component "$1"
    validate_revision "$2"
    validate_path "$3"
    commit=$("${component_git[@]}" rev-parse --verify "$2^{commit}" 2>/dev/null) ||
        die "revision does not resolve to a commit: $2"
    "${component_git[@]}" show --no-color "$commit:$3" ||
        die "cannot read $3 at $commit"
    ;;

ls-tree)
    (($# == 2 || $# == 3)) || {
        usage
        exit 2
    }
    open_component "$1"
    validate_revision "$2"
    commit=$("${component_git[@]}" rev-parse --verify "$2^{commit}" 2>/dev/null) ||
        die "revision does not resolve to a commit: $2"
    if (($# == 3)); then
        validate_path "$3"
        "${component_git[@]}" ls-tree -r --name-only "$commit" -- "$3"
    else
        "${component_git[@]}" ls-tree -r --name-only "$commit"
    fi | grep -Ev '(^|/)sources/restricted-microsoft(/|$)' || true
    ;;

search)
    (($# == 2)) || {
        usage
        exit 2
    }
    open_component "$1"
    validate_revision "$2"
    commit=$("${component_git[@]}" rev-parse --verify "$2^{commit}" 2>/dev/null) ||
        die "revision does not resolve to a commit: $2"
    pattern='security[ -]?(review|audit|assessment)|review-manifest\.json|agent-review|threat[ -]?model|assurance|claim[ -]boundar|security[ -]and[ -]limits|limits? of (the )?(claim|evidence)|verification evidence|test evidence|publication gate|release gate|policy alignment|hardening|CVE-[0-9]{4}-[0-9]+|security advisor|vulnerabilit|attack surface|trust boundar|fail-closed|residual risk|not formally verified|NOT RUN'
    set +e
    "${component_git[@]}" grep -I -n -i -E "$pattern" "$commit" -- \
        '*.md' '*.txt' '*.rst' '*.adoc' '*.json' \
        ':(exclude)*/sources/restricted-microsoft/*' \
        ':(exclude)sources/restricted-microsoft/*' \
        ':(exclude)*/sources/*' \
        ':(exclude)sources/*' \
        ':(exclude)*/docs/html/*' \
        ':(exclude)docs/html/*' \
        ':(exclude)*/reviews/*/html/*' \
        ':(exclude)reviews/*/html/*' \
        ':(exclude)*/node_modules/*' \
        ':(exclude)node_modules/*' \
        ':(exclude)*/build/*' \
        ':(exclude)build/*' \
        ':(exclude)*/tests/fixtures/*' \
        ':(exclude)tests/fixtures/*' \
        ':(exclude)*package-lock.json'
    result=$?
    set -e
    ((result == 0 || result == 1)) ||
        die "content search failed for $component_name at $commit"
    ;;

hash-file)
    (($# == 2)) || {
        usage
        exit 2
    }
    open_component "$1"
    validate_path "$2"
    parent=${2%/*}
    name=${2##*/}
    [[ $parent != "$2" ]] || parent=.
    resolved_parent=$(CDPATH= cd -- "$component_root/$parent" 2>/dev/null &&
        pwd -P) || die "cannot resolve file parent: $2"
    case $resolved_parent in
    "$component_root" | "$component_root"/*) ;;
    *) die "file escapes component: $2" ;;
    esac
    file=$resolved_parent/$name
    [[ -f $file && ! -L $file ]] || die "not a regular non-symlink file: $2"
    digest=$(sha256sum -- "$file") || die "cannot hash file: $2"
    printf 'logical-locator\t%s\n' "$(logical_file_locator "$2")"
    printf 'sha256\t%s\n' "${digest%% *}"
    printf 'checked\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ;;

*)
    usage
    exit 2
    ;;
esac
