#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>

set -u
export LC_ALL=C

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || {
    printf 'validate-agent: ERROR: cannot resolve repository root\n' >&2
    exit 2
}
cd -- "$repository_root" || exit 2

review_fixture_id=SR-20000101-001-fixture-review
executed_fixture_id=SR-20000101-002-fixture-executed
synthesis_fixture_id=SRS-20000101-001-fixture-synthesis
review_fixture=$repository_root/tests/fixtures/valid-review/$review_fixture_id
executed_fixture=$repository_root/tests/fixtures/valid-review-executed/$executed_fixture_id
synthesis_fixture=$repository_root/tests/fixtures/valid-synthesis/$synthesis_fixture_id
discovery_fixture=$repository_root/tests/fixtures/discovery-target

pass_count=0
fail_count=0

pass() {
    pass_count=$((pass_count + 1))
    printf 'ok   %s\n' "$*"
}

fail() {
    fail_count=$((fail_count + 1))
    printf 'FAIL %s\n' "$*"
}

sandbox=$(mktemp -d "${TMPDIR:-/tmp}/security-reviewer-tests.XXXXXX") || exit 2
cleanup() {
    rm -rf -- "$sandbox"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

require_file() {
    if [[ -f $1 ]]; then
        pass "file exists: ${1#"$repository_root/"}"
    else
        fail "file is missing: ${1#"$repository_root/"}"
    fi
}

require_executable() {
    if [[ -x $1 ]]; then
        pass "file is executable: ${1#"$repository_root/"}"
    else
        fail "file is not executable: ${1#"$repository_root/"}"
    fi
}

require_text() {
    if [[ -f $1 ]] && grep -Fq -- "$2" "$1"; then
        pass "${1#"$repository_root/"} states: $2"
    else
        fail "${1#"$repository_root/"} does not state: $2"
    fi
}

require_pattern() {
    if [[ -f $1 ]] && grep -Eq -- "$2" "$1"; then
        pass "${1#"$repository_root/"} matches: $2"
    else
        fail "${1#"$repository_root/"} does not match: $2"
    fi
}

refute_pattern() {
    if [[ -f $1 ]] && grep -Eq -- "$2" "$1"; then
        fail "${1#"$repository_root/"} must not match: $2"
    else
        pass "${1#"$repository_root/"} does not match: $2"
    fi
}

expect_pass() {
    local description=$1
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description (expected success, command failed)"
    fi
}

expect_fail() {
    local description=$1
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$description (expected failure, command succeeded)"
    else
        pass "$description"
    fi
}

expect_message() {
    local description=$1 needle=$2
    shift 2
    local output
    output=$("$@" 2>&1)
    if (($? == 0)); then
        fail "$description (expected failure, command succeeded)"
        return
    fi
    if printf '%s' "$output" | grep -Fq -- "$needle"; then
        pass "$description"
    else
        fail "$description (missing expected message: $needle)"
    fi
}

# A validation root carries the scripts, contracts, and fixture packages so
# the validator, the linter, and the synthesis input resolution all work
# without touching the repository.
copy_validation_root() {
    local root
    root=$(mktemp -d "$sandbox/validation.XXXXXX") || exit 2
    mkdir -p -- "$root/scripts" "$root/contracts" "$root/tests/fixtures"
    cp -- "$repository_root"/scripts/* "$root/scripts/" 2>/dev/null
    chmod +x "$root"/scripts/*.sh 2>/dev/null
    cp -- "$repository_root"/contracts/* "$root/contracts/" 2>/dev/null
    cp -R -- "$repository_root"/tests/fixtures/. "$root/tests/fixtures/"
    printf '%s' "$root"
}

review_path=tests/fixtures/valid-review/$review_fixture_id
executed_path=tests/fixtures/valid-review-executed/$executed_fixture_id
synthesis_path=tests/fixtures/valid-synthesis/$synthesis_fixture_id

printf '\n== repository contract ==\n'

for required in \
    .github/copilot-instructions.md \
    .github/agents/security-reviewer.agent.md \
    .github/agents/security-evidence.agent.md \
    .github/agents/security-research.agent.md \
    .github/agents/security-finding-review.agent.md \
    .github/skills/beryllium-security-review/SKILL.md \
    contracts/REVIEW-PROMPT.md \
    contracts/REVIEW-PROVENANCE.md \
    contracts/review-manifest.schema.json \
    contracts/review-manifest.template.json \
    README.md \
    AGENT-INTERFACE.md \
    RESEARCH-SOURCES.md \
    HANDOFF.md \
    SOURCE-DISCOVERY-LOG.md \
    SECURITY-REVIEWS.md \
    AUTHORS.md \
    LICENSES/GPL-3.0-only \
    outbox/pm-queue.md \
    inbox/README.md \
    scratch/README.md \
    .gitignore \
    scripts/lint-review-manifest.mjs \
    tests/test-review-manifest.mjs; do
    require_file "$repository_root/$required"
done

for template in scope execution-approvals evidence-ledger search-log \
    open-questions inaccessible-resources source-discoveries \
    publication-checklist HANDOFF review-iteration README SECURITY-REVIEW \
    00-executive-summary 01-scope-methodology 02-architecture-trust \
    03-findings 04-process-and-claims 05-positive-observations \
    06-hardening-backlog APPENDIX-evidence-map \
    synthesis-scope synthesis disposition-ledger synthesis-iteration; do
    require_file "$repository_root/templates/$template.md"
done

for script in readonly-inspect discover-security-material new-security-review \
    new-synthesis run-approved-command hash-evidence lint-review-manifest \
    validate-security-review update-index; do
    require_file "$repository_root/scripts/$script.sh"
    require_executable "$repository_root/scripts/$script.sh"
    if [[ -f $repository_root/scripts/$script.sh ]]; then
        expect_pass "scripts/$script.sh parses" bash -n \
            "$repository_root/scripts/$script.sh"
    fi
done
require_executable "$repository_root/tests/validate-agent.sh"
expect_pass "tests/validate-agent.sh parses" bash -n \
    "$repository_root/tests/validate-agent.sh"

printf '\n== licensing headers and portable content ==\n'

header_failures=0
checked_headers=0
while IFS= read -r file; do
    checked_headers=$((checked_headers + 1))
    case $file in
    *.md)
        pattern='^<!-- SPDX-License-Identifier: GPL-3.0-only -->$'
        ;;
    *.sh)
        pattern='^# SPDX-License-Identifier: GPL-3.0-only$'
        ;;
    *.mjs)
        pattern='^// SPDX-License-Identifier: GPL-3.0-only$'
        ;;
    esac
    # Agent files and SKILL.md carry the header after their front matter.
    if ! head -n 12 "$file" | grep -Eq -- "$pattern"; then
        fail "SPDX header is missing: ${file#"$repository_root/"}"
        header_failures=$((header_failures + 1))
    fi
    if ! head -n 12 "$file" | grep -Fq -- 'Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com>'; then
        fail "copyright line is missing: ${file#"$repository_root/"}"
        header_failures=$((header_failures + 1))
    fi
done < <(find "$repository_root" -path "$repository_root/.git" -prune -o \
    -path "$repository_root/inbox" -prune -o \
    -path "$repository_root/scratch" -prune -o \
    -type f \( -name '*.md' -o -name '*.sh' -o -name '*.mjs' \) -print | sort)
((header_failures > 0)) ||
    pass "SPDX and copyright headers present on $checked_headers tracked .md/.sh/.mjs files (fixtures included)"

path_failures=0
while IFS= read -r file; do
    if grep -aEq '(^|[^A-Za-z0-9_])/(home|Users|root)/' "$file"; then
        fail "absolute workstation path in tracked file: ${file#"$repository_root/"}"
        path_failures=$((path_failures + 1))
    fi
done < <(find "$repository_root" -path "$repository_root/.git" -prune -o \
    -path "$repository_root/inbox" -prune -o \
    -path "$repository_root/scratch" -prune -o \
    -path "$repository_root/LICENSES" -prune -o \
    -type f -print | sort)
((path_failures > 0)) || pass "no absolute workstation path in tracked files"

printf '\n== agent declarations and boundaries ==\n'

orchestrator=$repository_root/.github/agents/security-reviewer.agent.md
require_pattern "$orchestrator" '^name: security-reviewer$'
require_pattern "$orchestrator" '^user-invocable: true$'
require_pattern "$orchestrator" '^disable-model-invocation: true$'
require_pattern "$orchestrator" '^model: claude-opus-5$'
refute_pattern "$orchestrator" '^model: claude-fable-5.1$'
require_text "$orchestrator" 'reasoning effort `max`'
require_text "$orchestrator" 'context tier `long_context`'
for tool in read search execute edit agent web ask_user; do
    require_pattern "$orchestrator" "\"$tool\""
done
require_text "$orchestrator" '/beryllium-security-review'
if [[ -f $orchestrator ]] && head -n 1 "$orchestrator" | grep -Fqx -- '---'; then
    pass "orchestrator front matter starts at line 1"
else
    fail "orchestrator front matter must start at line 1"
fi

for specialist in security-evidence security-research security-finding-review; do
    agent=$repository_root/.github/agents/$specialist.agent.md
    require_pattern "$agent" "^name: $specialist\$"
    require_pattern "$agent" '^user-invocable: false$'
    require_pattern "$agent" '^model: claude-opus-5$'
    refute_pattern "$agent" '^model: claude-fable-5.1$'
    require_text "$agent" 'reasoning effort `max`'
    require_text "$agent" 'context tier `long_context`'
    require_text "$agent" 'later selection of `claude-fable-5.1`'
    refute_pattern "$agent" '"edit"'
    refute_pattern "$agent" '"execute"'
    refute_pattern "$agent" '"agent"'
    refute_pattern "$agent" '"ask_user"'
    if [[ -f $agent ]] && head -n 1 "$agent" | grep -Fqx -- '---'; then
        pass "$specialist front matter starts at line 1"
    else
        fail "$specialist front matter must start at line 1"
    fi
done
require_pattern "$repository_root/.github/agents/security-research.agent.md" '"web"'
refute_pattern "$repository_root/.github/agents/security-evidence.agent.md" '"web"'
refute_pattern "$repository_root/.github/agents/security-finding-review.agent.md" '"web"'

instructions=$repository_root/.github/copilot-instructions.md
skill=$repository_root/.github/skills/beryllium-security-review/SKILL.md
require_pattern "$skill" '^name: beryllium-security-review$'
pm_tasking_command='bash "${PWD%/*}/project-manager/scripts/project-tasking.sh" resolve .'
for document in "$orchestrator" "$instructions" "$skill" \
    "$repository_root/README.md" "$repository_root/AGENT-INTERFACE.md" \
    "$repository_root/HANDOFF.md"; do
    require_text "$document" "$pm_tasking_command"
done
for document in "$orchestrator" "$instructions" "$skill" \
    "$repository_root/README.md" "$repository_root/AGENT-INTERFACE.md"; do
    require_text "$document" 'not target execution'
    require_text "$document" 'session history'
    require_text "$document" 'task/todo database'
    require_text "$document" 'background agents'
    require_text "$document" 'prior chat'
    require_text "$document" 'memory'
done
for document in "$orchestrator" "$instructions" "$skill"; do
    require_text "$document" 'discovery over'
    require_text "$document" 'project-manager/outbox/component-requests.md'
    require_text "$document" 'not as authorization'
done
for phrase in 'read-only' 'SR-YYYYMMDD-NNN' 'private' 'NOT RUN' \
    'not formally verified' 'risk acceptance' 'restricted-microsoft'; do
    require_text "$instructions" "$phrase"
done
for phrase in 'APPROVAL-NNN' 'EFFECTIVE SECURITY-REVIEW SCOPE' \
    'Independent review' 'Synthesis' 'Edit scope' 'Cancel' \
    'run-approved-command.sh' 'REVIEW-ITERATION-NNN' 'Human review target'; do
    require_text "$skill" "$phrase"
done
require_text "$instructions" 'never grants or infers'
for document in "$skill" "$orchestrator" \
    "$repository_root/README.md" "$repository_root/AGENT-INTERFACE.md"; do
    require_pattern "$document" '([Nn]ever|[Dd]o not|not) (grant|grants|infer|infers|imply)'
done
for document in "$repository_root/templates/01-scope-methodology.md" \
    "$repository_root/templates/04-process-and-claims.md" \
    "$repository_root/templates/SECURITY-REVIEW.md"; do
    require_text "$document" 'accepted through R7'
    require_text "$document" 'R8-H0 is a committed candidate and'
    require_text "$document" 'NOT RUN'
    require_text "$document" 'never grants or infers'
done
require_text "$repository_root/templates/execution-approvals.md" 'No approvals recorded.'
require_text "$repository_root/templates/execution-approvals.md" '- Quoted approval: "'
require_text "$repository_root/templates/03-findings.md" '- Alternatives and counter-evidence:'
require_text "$repository_root/templates/03-findings.md" 'No findings recorded.'
require_text "$repository_root/outbox/pm-queue.md" 'SRQ-'

printf '\n== manifest linter unit tests ==\n'

if ! command -v node >/dev/null 2>&1; then
    fail "node is required for tests/test-review-manifest.mjs but is not in PATH"
elif [[ ! -f $repository_root/tests/test-review-manifest.mjs ]]; then
    fail "tests/test-review-manifest.mjs is missing"
else
    expect_pass "node tests/test-review-manifest.mjs passes" \
        node "$repository_root/tests/test-review-manifest.mjs"
fi

printf '\n== package scaffolding ==\n'

scaffold=$sandbox/scaffold
mkdir -p -- "$scaffold/scripts" "$scaffold/templates" "$scaffold/contracts"
cp -- "$repository_root"/scripts/* "$scaffold/scripts/" 2>/dev/null
cp -- "$repository_root"/templates/* "$scaffold/templates/"
cp -- "$repository_root"/contracts/* "$scaffold/contracts/" 2>/dev/null
chmod +x "$scaffold"/scripts/*.sh 2>/dev/null

expect_fail "new-security-review rejects a missing argument" \
    "$scaffold/scripts/new-security-review.sh"
expect_fail "new-security-review rejects an uppercase slug" \
    "$scaffold/scripts/new-security-review.sh" Bad-Slug "Bad slug"
expect_fail "new-security-review rejects a leading hyphen" \
    "$scaffold/scripts/new-security-review.sh" -bad "Bad slug"
expect_fail "new-security-review rejects a 42-character slug" \
    "$scaffold/scripts/new-security-review.sh" \
    aaaaaaaaaabbbbbbbbbbccccccccccddddddddddee "Too long"
expect_fail "new-security-review rejects a title with a table delimiter" \
    "$scaffold/scripts/new-security-review.sh" good-slug "Bad | title"
expect_fail "new-synthesis rejects a missing argument" \
    "$scaffold/scripts/new-synthesis.sh"

first=$(cd "$scaffold" && scripts/new-security-review.sh first-review "First review" 2>/dev/null)
second=$(cd "$scaffold" && scripts/new-security-review.sh second-review "Second review" 2>/dev/null)
synthesis=$(cd "$scaffold" && scripts/new-synthesis.sh first-synthesis "First synthesis" 2>/dev/null)
if [[ $first == reviews/SR-*-001-first-review &&
    $second == reviews/SR-*-002-second-review ]]; then
    pass "new-security-review allocates collision-safe daily package IDs"
else
    fail "new-security-review returned unexpected paths: $first $second"
fi
if [[ $synthesis == syntheses/SRS-*-001-first-synthesis ]]; then
    pass "new-synthesis allocates syntheses/SRS-YYYYMMDD-NNN-<short-name>"
else
    fail "new-synthesis returned unexpected path: $synthesis"
fi
if [[ -f $scaffold/$first/iterations/REVIEW-ITERATION-001.md &&
    -f $scaffold/$first/execution-approvals.md &&
    -f $scaffold/$first/03-findings.md &&
    -f $scaffold/$first/review-manifest.json ]]; then
    pass "scaffolded review package carries the manifest, approvals, findings, and first iteration"
else
    fail "scaffolded review package is incomplete"
fi
if [[ -f $scaffold/$synthesis/iterations/SYNTHESIS-ITERATION-001.md &&
    -f $scaffold/$synthesis/disposition-ledger.md &&
    -f $scaffold/$synthesis/synthesis.md ]]; then
    pass "scaffolded synthesis package carries synthesis.md, the disposition ledger, and first iteration"
else
    fail "scaffolded synthesis package is incomplete"
fi
if grep -rFq '@@' "$scaffold/reviews" "$scaffold/syntheses" 2>/dev/null; then
    fail "scaffolded packages contain unsubstituted template tokens"
else
    pass "scaffolded packages contain no unsubstituted template token"
fi

expect_pass "scaffolded review package passes draft validation" \
    bash -c "cd '$scaffold' && scripts/validate-security-review.sh --draft '$first'"
expect_fail "scaffolded review package fails completion validation" \
    bash -c "cd '$scaffold' && scripts/validate-security-review.sh '$first'"
expect_pass "scaffolded synthesis package passes draft validation" \
    bash -c "cd '$scaffold' && scripts/validate-security-review.sh --draft '$synthesis'"
expect_fail "scaffolded synthesis package fails completion validation" \
    bash -c "cd '$scaffold' && scripts/validate-security-review.sh '$synthesis'"
expect_pass "update-index regenerates a package index" \
    bash -c "cd '$scaffold' && scripts/update-index.sh"
expect_pass "update-index --check accepts a current index" \
    bash -c "cd '$scaffold' && scripts/update-index.sh --check"
for needle in '## Reviews' '## Syntheses' \
    '| Package ID | Title | Created | Status | Phase | Execution | Distribution | Target | Latest iteration |' \
    '| Package ID | Title | Created | Status | Distribution | Inputs | Latest iteration |' \
    'first-review' 'second-review' 'first-synthesis'; do
    if grep -Fq -- "$needle" "$scaffold/SECURITY-REVIEWS.md"; then
        pass "generated index contains: $needle"
    else
        fail "generated index is missing: $needle"
    fi
done
printf 'stale\n' >>"$scaffold/SECURITY-REVIEWS.md"
expect_fail "update-index --check rejects a stale index" \
    bash -c "cd '$scaffold' && scripts/update-index.sh --check"

printf '\n== completed package validation ==\n'

root=$(copy_validation_root)
for fixture_path in "$review_path" "$executed_path" "$synthesis_path"; do
    expect_pass "${fixture_path##*/} passes completion validation" \
        bash -c "cd '$root' && scripts/validate-security-review.sh '$fixture_path'"
    expect_pass "${fixture_path##*/} passes draft validation" \
        bash -c "cd '$root' && scripts/validate-security-review.sh --draft '$fixture_path'"
    expect_pass "${fixture_path##*/} passes baseline validation against itself" \
        bash -c "cd '$root' && scripts/validate-security-review.sh --baseline '$fixture_path' '$fixture_path'"
done
if [[ -x $root/scripts/lint-review-manifest.sh ]]; then
    expect_pass "static-only fixture manifest lints" \
        bash -c "cd '$root' && scripts/lint-review-manifest.sh '$review_path/review-manifest.json'"
    expect_pass "execution-backed fixture manifest lints" \
        bash -c "cd '$root' && scripts/lint-review-manifest.sh '$executed_path/review-manifest.json'"
else
    fail "scripts/lint-review-manifest.sh is missing; manifest lint is untested"
fi

root=$(copy_validation_root)
rm -- "$root/$executed_path/evidence/APPROVAL-001/stdout.log"
expect_message "rejects an executed approval whose evidence file is missing" \
    'evidence/APPROVAL-001/stdout.log is missing' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$executed_path'"

root=$(copy_validation_root)
printf 'tampered\n' >>"$root/$executed_path/evidence/APPROVAL-001/stdout.log"
expect_message "rejects a retained evidence file whose hash changed" \
    'hash mismatch' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$executed_path'"

root=$(copy_validation_root)
sed -i "s|^- Command: \`printf 'fixture\\\\n'\`|- Command: \`printf 'other'\`|" \
    "$root/$executed_path/execution-approvals.md"
expect_message "rejects an approval whose command text differs from the manifest" \
    'command text differs' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$executed_path'"

root=$(copy_validation_root)
sed -i 's/^- Status: `executed`$/- Status: `approved`/' \
    "$root/$executed_path/execution-approvals.md"
expect_message "rejects a manifest command whose approval is not executed" \
    'requires Status executed' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$executed_path'"

root=$(copy_validation_root)
sed -i 's/^Execution: `static-only`$/Execution: `execution-backed`/' \
    "$root/$review_path/scope.md"
expect_message "rejects a scope Execution that differs from the manifest classification" \
    'classification equals scope Execution' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
sed -i 's/^- Severity: `Medium`$/- Severity: `Severe`/' \
    "$root/$review_path/03-findings.md"
expect_message "rejects an invalid finding severity" \
    'invalid Severity' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
sed -i '/^- Alternatives and counter-evidence: None identified\.$/d' \
    "$root/$review_path/03-findings.md"
expect_message "rejects a finding without the full bullet key set" \
    'bullet keys in order' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
sed -i "0,/$review_fixture_id-E0002/s//$review_fixture_id-E0099/" \
    "$root/$review_path/03-findings.md"
expect_message "rejects a dangling evidence reference" \
    'evidence reference is not defined' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
printf '\nEvidence copy: /%s\n' 'home/example/private.txt' >>"$root/$review_path/README.md"
expect_message "rejects an absolute workstation path" \
    'absolute workstation path' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
printf '\nCompare SR-20000101-009-other-review.\n' >>"$root/$review_path/README.md"
expect_message "rejects a foreign review package identifier (independence)" \
    'foreign review package identifiers' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
printf '\nCompare agent-review/some-model/03-findings.md.\n' >>"$root/$review_path/README.md"
expect_message "rejects a target-side agent-review package reference (independence)" \
    'agent-review/<pkg>/' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
rm -- "$root/$review_path/04-process-and-claims.md"
expect_message "rejects a missing required artifact" \
    'required package artifact is missing' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
sed -i 's/^| helium-te-poc | `component:\/\/helium-te-poc` |/| not-registered | `component:\/\/not-registered` |/' \
    "$root/$review_path/scope.md"
expect_message "rejects an unregistered snapshot component" \
    'not a registered target' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
find "$root/$review_path" -type f -name '*.md' \
    -exec sed -i 's/Distribution: `private`/Distribution: `internal`/' {} +
expect_message "rejects promotion without a human record" \
    'HUMAN-PROMOTION-NNN' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"

root=$(copy_validation_root)
mkdir -p -- "$root/baseline"
cp -R -- "$review_fixture" "$root/baseline/"
printf '\nchanged\n' >>"$root/$review_path/iterations/REVIEW-ITERATION-001.md"
expect_message "rejects an edited append-only iteration" \
    'append-only iteration changed' \
    bash -c "cd '$root' && scripts/validate-security-review.sh --baseline 'baseline/$review_fixture_id' '$review_path'"

root=$(copy_validation_root)
sed -i 's/^Status: `Complete`$/Status: `Draft`/' "$root/$review_path/scope.md"
expect_message "rejects a synthesis whose input package is not Complete" \
    'must have Status Complete' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$synthesis_path'"

root=$(copy_validation_root)
sed -i 's/1111111111111111111111111111111111111111/3333333333333333333333333333333333333333/' \
    "$root/$synthesis_path/scope.md"
expect_message "rejects a synthesis input commit that differs from the input manifest" \
    'differs from the input manifest' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$synthesis_path'"

root=$(copy_validation_root)
sed -i 's/| `Confirmed` | REV-P2-01 |/| `Implemented` | REV-P2-01 |/' \
    "$root/$synthesis_path/disposition-ledger.md"
expect_message "rejects a synthesis disposition outside the vocabulary" \
    'is invalid: Implemented' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$synthesis_path'"

root=$(copy_validation_root)
sed -i '/^| FINDING-001 | SR-20000101-001-fixture-review |/d' \
    "$root/$synthesis_path/disposition-ledger.md"
expect_message "rejects a synthesis that drops a source finding" \
    'has no disposition row' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$synthesis_path'"

root=$(copy_validation_root)
rm -f -- "$root/scripts/lint-review-manifest.sh"
expect_message "completion mode fails clearly when the manifest linter is absent" \
    'manifest lint helper is missing' \
    bash -c "cd '$root' && scripts/validate-security-review.sh '$review_path'"
expect_pass "draft mode does not require the manifest linter" \
    bash -c "cd '$root' && scripts/validate-security-review.sh --draft '$review_path'"

printf '\n== deterministic discovery and read-only inspection ==\n'

workspace=$sandbox/workspace
component=$workspace/helium-te-poc
toolroot=$workspace/security-reviewer
mkdir -p -- "$workspace" "$component" "$toolroot/scripts"
cp -- "$repository_root/scripts/readonly-inspect.sh" \
    "$repository_root/scripts/discover-security-material.sh" "$toolroot/scripts/"
chmod +x "$toolroot"/scripts/*.sh
cp -R -- "$discovery_fixture"/. "$component/"

git -C "$workspace" init -q -b main
git -C "$workspace" config user.name Fixture
git -C "$workspace" config user.email fixture@example.invalid
printf 'fixture workspace\n' >"$workspace/README.md"
git -C "$workspace" add README.md
git -C "$workspace" commit -q -m 'fixture workspace'

git -C "$component" init -q -b main
git -C "$component" config user.name Fixture
git -C "$component" config user.email fixture@example.invalid
git -C "$component" add .
git -C "$component" commit -q -m 'fixture target'

head_before=$(git -C "$component" rev-parse HEAD)
status_before=$(git -C "$component" status --porcelain)
index_before=$(sha256sum "$component/.git/index")
output=$(
    cd "$toolroot" &&
        scripts/discover-security-material.sh component helium-te-poc HEAD
)
head_after=$(git -C "$component" rev-parse HEAD)
status_after=$(git -C "$component" status --porcelain)
index_after=$(sha256sum "$component/.git/index")

if [[ $head_before == "$head_after" && $status_before == "$status_after" &&
    $index_before == "$index_after" ]]; then
    pass "discovery leaves target HEAD, worktree, and index unchanged"
else
    fail "discovery changed target state"
fi

for needle in \
    'Prior security review' \
    'Threat model' \
    'Assurance or claim boundary' \
    'Design input' \
    'Test or verification evidence' \
    'Release or publication gate' \
    'component://helium-te-poc/agent-review/some-package/review-manifest.json' \
    'component://helium-te-poc/security-review.md' \
    'component://helium-te-poc/threat-model.md' \
    'component://helium-te-poc/docs/security-and-limits.md' \
    'component://helium-te-poc/docs/publication-gate.md' \
    'component://helium-te-poc/SECURITY.md'; do
    if printf '%s\n' "$output" | grep -Fq -- "$needle"; then
        pass "discovery reports: $needle"
    else
        fail "discovery output is missing: $needle"
    fi
done
for needle in 'Stale' 'Conflicting' 'Irrelevant'; do
    if printf '%s\n' "$output" | awk -F '\t' 'NR > 2 { print $4 }' | grep -Fqx -- "$needle"; then
        fail "discovery must not assign the human-only class: $needle"
    else
        pass "discovery never assigns the human-only class: $needle"
    fi
done
if printf '%s\n' "$output" | grep -Fq 'restricted-microsoft'; then
    fail "discovery must exclude restricted-microsoft (top-level and nested)"
else
    pass "discovery excludes restricted-microsoft (top-level and nested)"
fi

state_output=$("$toolroot/scripts/readonly-inspect.sh" state helium-te-poc 2>/dev/null)
if [[ $state_output == "commit $head_before"$'\n'"branch refs/heads/main"$'\n'"dirty false" ]]; then
    pass "readonly-inspect state prints commit, branch, and dirty lines exactly"
else
    fail "readonly-inspect state output is malformed: $state_output"
fi
printf 'scratch\n' >"$component/untracked.md"
state_output=$("$toolroot/scripts/readonly-inspect.sh" state helium-te-poc 2>/dev/null)
if printf '%s\n' "$state_output" | grep -Fqx 'dirty true' &&
    printf '%s\n' "$state_output" | grep -Fqx 'dirty-path untracked.md'; then
    pass "readonly-inspect state reports dirty paths with the dirty-path prefix"
else
    fail "readonly-inspect state did not report the dirty path: $state_output"
fi
rm -f -- "$component/untracked.md"
git -C "$component" checkout -q --detach HEAD
state_output=$("$toolroot/scripts/readonly-inspect.sh" state helium-te-poc 2>/dev/null)
if printf '%s\n' "$state_output" | grep -Fqx 'branch detached'; then
    pass "readonly-inspect state reports a detached HEAD as detached"
else
    fail "readonly-inspect state did not report detached: $state_output"
fi
git -C "$component" checkout -q main

path_output=$("$toolroot/scripts/readonly-inspect.sh" path helium-te-poc 2>/dev/null)
if [[ $path_output == "$(CDPATH= cd -- "$component" && pwd -P)" ]]; then
    pass "readonly-inspect path prints the resolved component directory"
else
    fail "readonly-inspect path returned: $path_output"
fi
expect_fail "readonly-inspect path rejects an unregistered component" \
    "$toolroot/scripts/readonly-inspect.sh" path not-registered
expect_fail "readonly-inspect path rejects an absent registered component" \
    "$toolroot/scripts/readonly-inspect.sh" path beryllium-repo
expect_fail "readonly-inspect rejects security-reviewer itself" \
    "$toolroot/scripts/readonly-inspect.sh" path security-reviewer
components_output=$("$toolroot/scripts/readonly-inspect.sh" components 2>/dev/null)
for name in beryllium-repo helium-te-poc formal-verification-research osr-claude \
    provenance-review analysis-workbook threat-modeler project-manager \
    cheri-riscv-notes-repo xrv-research-repo; do
    if printf '%s\n' "$components_output" | grep -Eq "^$name	"; then
        pass "readonly-inspect components lists $name"
    else
        fail "readonly-inspect components does not list $name"
    fi
done
expect_fail "readonly-inspect rejects an unregistered component" \
    "$toolroot/scripts/readonly-inspect.sh" state not-registered
expect_fail "readonly-inspect rejects a malformed revision" \
    "$toolroot/scripts/readonly-inspect.sh" resolve helium-te-poc \
    --upload-pack=bad
expect_fail "readonly-inspect rejects path traversal" \
    "$toolroot/scripts/readonly-inspect.sh" show helium-te-poc HEAD ../escape
expect_fail "readonly-inspect rejects restricted source paths" \
    "$toolroot/scripts/readonly-inspect.sh" show helium-te-poc HEAD \
    sources/restricted-microsoft/secret.md
expect_fail "readonly-inspect rejects nested restricted source paths" \
    "$toolroot/scripts/readonly-inspect.sh" show helium-te-poc HEAD \
    nested/sources/restricted-microsoft/secret.md
if "$toolroot/scripts/readonly-inspect.sh" ls-tree helium-te-poc HEAD 2>/dev/null |
    grep -Fq 'restricted-microsoft'; then
    fail "readonly-inspect ls-tree must exclude restricted-microsoft"
else
    pass "readonly-inspect ls-tree excludes restricted-microsoft"
fi

printf '\n== generated repository state ==\n'

expect_pass "committed SECURITY-REVIEWS.md is current" \
    "$repository_root/scripts/update-index.sh" --check
require_text "$repository_root/SECURITY-REVIEWS.md" '## Reviews'
require_text "$repository_root/SECURITY-REVIEWS.md" '## Syntheses'

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
((fail_count == 0)) || exit 1
