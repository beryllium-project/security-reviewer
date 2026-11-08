<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-reviewer handoff

**Last updated:** 2026-11-08 (UTC)

## Overall position

The component was created on 2026-09-06 by extracting and generalizing the
Helium proof-of-concept review contract at commit
`9b3ff4e9441e5b4434a8ec37794dee1d941e11ef` (branch
`helium-te-travel-fedora44`); see `AUTHORS.md` for the per-file derivation
record. Helium was read only and not changed.

The Project Manager's latest validated baseline is clean local `main` at
handoff return `c2edac70afdfe5b0bb90e237487cd168fb91e900`, two commits ahead
of last-fetched public `origin/main` at
`2e8d2054840af35ba6d64a00546ee99806a88dfb`. Work
`2bb4c989bbe9b57f870e6f653ed3732e742b11f9` and return `c2edac7` close
`PMR-109` and `PMR-110`. The responsible human subsequently replied `"done"`,
releasing that owner session and reservation; the prior return-time held-state
wording is obsolete.

P0 `PMR-138` (`PMD-20261108-001`) replaces the published history after
`c2edac7`. Its single replacement commit, with parent `c2edac7`, contains
this handoff and carries forward the earlier publication-safe model
provenance maintenance and the `PMR-118` / `PMR-123` owner return without any
embedded denylisted identifier or identifier-specific check; the replaced
commits are identified only in private parent records. Non-public model
identifiers are recorded as `unlisted` with a `/package/model_id`
qualification, and the publication checklist and process contract are
aligned. The package validator and the repository suite delegate
denylisted-term detection to the shared publication gate's `scan-tree` when
it is installed and otherwise print a notice and skip that scan; their tests
use a synthetic term. The carried-forward maintenance also corrects stale
public-origin and publication-authority wording.

`PMR-118` and `PMR-123` (`PMD-20261006-001`) are carried unchanged in
substance by the same replacement commit. Every session reads and SHA-checks
the `workspace://SOT.md` startup anchor before any target, sibling,
component, or tasking resolution, and all four profiles use
`claude-opus-5.5` with reasoning effort `max` and context tier
`long_context`. A security review runs only on explicit responsible-human
request and is not standard practice. The responsible human runs every Git
command, including the history rewrite; the `PMR-138` owner session ran no
Git command in this component.

The repository was first pushed public on 2026-09-06, and `PMD-20261012-002`
records the responsible human's decision to keep it public. On 2026-11-08
`main` was pushed to the public `origin` through `2bb4c98`, `c2edac7`, and
the two later commits that `PMR-138` replaces, and the responsible human
decided to make the repository private for repair and public again
afterwards (`PMD-20261108-002`). After the rewrite, local `main` is the
replacement commit on `c2edac7` and has diverged from the remote-tracking
`origin/main`, which holds the replaced commits until the force push with
lease. `PMR-111` is superseded by `PMR-138`. The force push, both visibility
changes, and any GitHub Support cache-purge request are responsible-human
actions; until `PMR-138` closes, no other push of this component occurs.

No engagement has been run: `reviews/` and `syntheses/` are empty,
`SECURITY-REVIEWS.md` records an empty package set, the discovery log has no
source rows, and the Project Manager queue is empty.

## What exists

- one user-facing `security-reviewer` orchestrator
  (`.github/agents/security-reviewer.agent.md`) and three write-disabled
  specialists (`security-evidence`, `security-research`,
  `security-finding-review`), all pinned to `claude-opus-5.5` with invocation
  defaults reasoning effort `max` and context tier `long_context`; there is no
  role-specific model, lower effort, other context tier, or per-invocation
  override, and an unavailable value stops without silent fallback; a
  security review runs only on explicit responsible-human request and is not
  standard practice (`PMD-20261006-001`);
- the `workspace://SOT.md` startup anchor: before any target, sibling,
  component, or tasking resolution the orchestrator reads the current anchor,
  hashes it with `bash ./scripts/readonly-inspect.sh hash-file workspace SOT.md`,
  and compares the digest with the one pinned in its generated Project Manager
  tasking view; the specialists read the anchor and require the
  orchestrator's matching startup-anchor record;
- publication-safe model provenance across the active instructions, agent
  profiles, skill, review contract, manifest linter, package validator,
  templates, fixtures, and tests; `unlisted` requires a
  `/package/model_id` qualification; no denylisted identifier is embedded
  in any form, and the package validator and the repository suite delegate
  denylisted-term detection to the shared publication gate's `scan-tree`
  when it is installed, printing a notice and skipping that scan otherwise;
- the `beryllium-security-review` skill
  (`.github/skills/beryllium-security-review/SKILL.md`) with guided intake,
  exact-revision freeze, deterministic discovery, the `Independent review |
  Synthesis` mode gate, the `APPROVAL-NNN` approved-execution workflow, the
  Helium report set, the synthesis method, and the `Human review target`
  reply contract;
- the exact fail-closed Project Manager startup resolver for
  `check Project Manager tasking`:
  `bash "${PWD%/*}/project-manager/scripts/project-tasking.sh" resolve .`;
  it is the sole sibling-command exception, is outside every package, and has
  no session-history, task/todo-database, background-agent, prior-chat, or
  memory fallback;
- repository instructions, `AGENT-INTERFACE.md`, `RESEARCH-SOURCES.md`,
  `README.md`, `SOURCE-DISCOVERY-LOG.md`, `outbox/pm-queue.md`, and the
  `inbox/` and `scratch/` policy files;
- the generalized review contract under `contracts/` (prompt, provenance
  contract, manifest schema `urn:beryllium:security-review-manifest:1.0.0`,
  template);
- maintained scripts under `scripts/` (read-only inspection, discovery,
  scaffolders, approved-command runner, evidence hasher, manifest linter and
  wrapper, validator, index generator), package templates under
  `templates/`, and the contract suite under `tests/` with synthetic
  fixtures;
- `LICENSES/GPL-3.0-only` and `AUTHORS.md`.

## How to validate

From this repository:

```sh
bash ./tests/validate-agent.sh
bash ./scripts/update-index.sh --check
git diff --check
```

`tests/validate-agent.sh` runs the maintained contract checks including the
linter unit tests (`node tests/test-review-manifest.mjs`). At creation on
2026-09-06 the authoring Copilot session observed `259 passed, 0 failed`
from the suite and `PASS (93 checks)` from the linter tests on this tree;
that is an agent observation, not a human validation, and the responsible
human should re-run the suite before relying on it. For the `PMR-074` owner
change on 2026-09-16, this session observed `321 passed, 0 failed`;
`bash ./scripts/update-index.sh --check` and `git diff --check` also exited 0.
For the earlier publication-safety and status-maintenance tree, which
`PMR-138` replaced, its authoring session observed
`bash ./tests/validate-agent.sh`: `416 passed, 0 failed`; and
`bash ./scripts/update-index.sh --check`: exit 0. The agent did not run
`git diff --check` because direct Git is prohibited in this component.
For the `PMR-118` / `PMR-123` tree, which `PMR-138` also replaced, its owner
session observed
`bash ./tests/validate-agent.sh`: `483 passed, 0 failed`;
`bash ./scripts/update-index.sh --check`: exit 0; and `git diff --check`:
exit 0. At the responsible human's explicit direction to verify the exact
HEAD and a clean worktree, that session used read-only Git queries with
optional locks disabled; it staged and committed nothing.
For the `PMR-138` replacement tree, this session observed
`bash ./tests/validate-agent.sh`: `487 passed, 0 failed`, including the
installed publication gate's `scan-tree` over 124 publishable repository
files with no denylisted term and the synthetic-term delegation tests; and
`bash ./scripts/update-index.sh --check`: exit 0. This session ran no Git
command in this component, so `git diff --check` is left to the responsible
human. Where the gate is not installed, the suite and the validator print a
`skip` or `note` line instead of scanning for denylisted terms.

## Open items

- **P0 `PMR-138` closure.** The responsible human audits the repaired local
  history with the publication gate, decides the force push with lease with
  a new same-turn confirmation, and then runs
  `git fetch --prune --tags origin`; the Project Manager closes `PMR-138`
  once its `audit --all-refs` of this clone passes and, after any return to
  public visibility, confirms the live view with `audit --remote origin`.
  The GitHub Support cache-purge request and the return to public visibility
  are separate responsible-human decisions.
- **Project Manager verification of `PMR-118` and `PMR-123`.** Both are
  returned `completed` below in the replacement commit containing this
  handoff; the Project Manager verifies them against it after the rewrite and
  closes them independently.
- **Remaining sibling target registration is owner-side.** Threat-modeler
  registered `security-reviewer` at owner commit `c4126b6`; the
  analysis-workbook registration remains requested as `PMR-050`.
- **No other push.** `PMR-111` is superseded by `PMR-138`. Until `PMR-138`
  closes, its force push with lease is the only push of this component.
- **No first engagement.** The workflow has been exercised only against
  synthetic fixtures by the maintained suite, not against a real target. A
  security review runs only on explicit responsible-human request; none is
  pending.

## Known limitations

- One review package covers exactly one registered component snapshot; a
  multi-component review is several packages plus a synthesis.
- Approved execution runs a command in the target checkout under a clean
  environment but cannot prevent the command itself from writing there; the
  runner records post-run dirty paths so that any such write is visible. A
  dirty result is reported, never cleaned.
- The manifest and approval records are attestations; validation checks
  consistency, not truth.
- The independence heuristic in the validator catches foreign package IDs and
  `agent-review/<package>/` paths; the rule itself is binding beyond what the
  heuristic catches.
- Promotion, implementation authorization, acceptance, review approval, and
  assurance claims remain responsible-human gates even if structural
  validation succeeds.
- The startup anchor check depends on the generated Project Manager tasking
  view for its pinned digest. A missing view or digest stops startup even
  when the anchor itself is unchanged, and the write-disabled specialists,
  which cannot hash files, rely on the orchestrator's startup-anchor record.
- The denylisted-term scan in the validator and the suite runs only where the
  shared publication gate is installed; elsewhere it prints a notice and is
  skipped, so a passing run there says nothing about denylisted terms.

## Restartable next action

The responsible human audits the repaired local branches and tags with the
publication gate as specified in the private incident note
`workspace://.publication-gate/P0-20261108-001.md`, continues only on
`PASS`, decides with a new same-turn confirmation the force push with lease
of this replacement commit, and then runs `git fetch --prune --tags origin`.
The Project Manager then runs `audit --all-refs` of this clone, closes
`PMR-138` when it passes, and verifies `PMR-118` and `PMR-123` against the
replacement commit. Do not push anything else, keep a branch or tag at a
replaced commit, or begin an engagement as part of this maintenance.

## Coordination update

The Project Manager carried only registration, backup, source-pointer, and
current-state coordination wording under `PMR-030`, `PMR-031`, `PMR-033`,
`PMR-056`, `PMR-060`, and class 3 of `PMD-20260904-003`. The Project Manager
did not run an engagement, modify review content, grant a gate, or push this
component.

The startup resolver validated Project Manager commit
`e195ac84b672d15e86dca2eb0f591745bdd0f81d` and request-table blob
`d1444c36ae3cbe5ff29c24678997c22db7130945`. It returned `PMR-050`, assigned
to `analysis-workbook`, and `PMR-074`, assigned to this component. The
responsible human selected `PMR-074`; the resolver output was treated as
discovery, not authorization.

On 2026-11-08 (UTC) the startup resolver validated Project Manager commit
`a874b19f2e6fbca2a0ec3007b381f339af6d3bd1`, request-table blob
`3f9c8dcfe5295cd9efdf096c3b25de7edaac288e`, and `workspace://SOT.md`
SHA-256 `7fa17e4eaf4fb37096f4bd2aef853e399b025e4d3271d88db5cee6ac02284552`.
It returned `PMR-111`, `PMR-118`, and `PMR-123`, all assigned to this
component. The responsible human selected `PMR-118` and `PMR-123` together
in a direct human-started ordinary session on `claude-opus-5.5` / `max` /
`long_context`, without `--agent security-reviewer` and without the
owner-session launcher, so no launcher writer reservation was held. The
session first stopped on a dirty worktree and an active prior session in this
component; it resumed after the responsible human committed the earlier
publication-safety maintenance and reported that session exited, and a
re-check found a clean worktree and no other Copilot process here. `PMR-111`
was not selected. The resolver output was treated as discovery, not
authorization.

On 2026-11-08 (UTC) a human-run owner-session launcher packet selected
`PMR-138` and `PMR-141` for one ordinary owner session; its SHA-256 and the
expected branch and HEAD were verified before startup. The startup resolver
validated Project Manager commit `d8fcec4b8422260df95c25c7d0310b87a253b198`,
request-table blob `36dfb9e0b2774ced529d98703adc2675cf5e8e74`, and
`workspace://SOT.md` SHA-256
`7fa17e4eaf4fb37096f4bd2aef853e399b025e4d3271d88db5cee6ac02284552`, and
returned `PMR-138`, `PMR-141`, `PMR-118`, and `PMR-123`. Only `PMR-138` and
`PMR-141` were selected; the `PMR-118` / `PMR-123` returns are carried
forward by the replacement commit for Project Manager verification. The
responsible human confirmed the logical and physical workspace entry, a clean
worktree, and no other writer. The private incident note was read as tasking
evidence. The resolver output was treated as discovery, not authorization.
`PMR-141` is handled separately after the replacement commit.

## Project Manager return

| Related IDs | Result | Evidence | Validation | Repository state | Requested Project Manager action |
| --- | --- | --- | --- | --- | --- |
| `PMR-062` | `completed` | Single owner commit containing this row, with parent `79c664f6130ec1e740282e6dd0ebe6fe6d136ea1`; `.github/agents/security-reviewer.agent.md`, `.github/agents/security-evidence.agent.md`, `.github/agents/security-research.agent.md`, `.github/agents/security-finding-review.agent.md`, `.github/copilot-instructions.md`, `.github/skills/beryllium-security-review/SKILL.md`, `tests/validate-agent.sh` | `bash ./tests/validate-agent.sh`: `319 passed, 0 failed`; `bash ./scripts/update-index.sh --check`: exit 0 | `main`; fifth local commit ahead of private `origin/main` at `9ca5071b450eae39f63f7e31f61ad3e7009070e0`; not pushed; no remote backup of this commit; exact post-amend SHA returned separately | Verify the returned owner commit and close `PMR-062` independently |
| `PMR-065` | `completed` | Same single owner commit containing this row, with parent `79c664f6130ec1e740282e6dd0ebe6fe6d136ea1`; `.github/agents/security-reviewer.agent.md`, `.github/copilot-instructions.md`, `.github/skills/beryllium-security-review/SKILL.md`, `AGENT-INTERFACE.md`, `README.md`, `HANDOFF.md`, `tests/validate-agent.sh` | `bash ./tests/validate-agent.sh`: `319 passed, 0 failed`; `bash ./scripts/update-index.sh --check`: exit 0 | `main`; fifth local commit ahead of private `origin/main` at `9ca5071b450eae39f63f7e31f61ad3e7009070e0`; not pushed; no remote backup of this commit; exact post-amend SHA returned separately | Verify the returned owner commit and close `PMR-065` independently |
| `PMR-074` | `completed` | Single owner commit containing this row, with parent `f2051a4b70ab211a943fe3e2fa38221f6df02d44`; `.github/agents/security-reviewer.agent.md`, `.github/agents/security-evidence.agent.md`, `.github/agents/security-research.agent.md`, `.github/agents/security-finding-review.agent.md`, `.github/copilot-instructions.md`, `.github/skills/beryllium-security-review/SKILL.md`, `tests/validate-agent.sh`, `AGENT-INTERFACE.md`, `README.md`, `HANDOFF.md` | `bash ./tests/validate-agent.sh`: `321 passed, 0 failed`; `bash ./scripts/update-index.sh --check`: exit 0; `git diff --check`: exit 0 | `main`; one local commit ahead of private `origin/main` at `f2051a4b70ab211a943fe3e2fa38221f6df02d44`; not pushed; no remote backup of this commit; exact SHA returned separately | Verify the returned owner commit and close `PMR-074` independently |
| `PMR-109` | `completed` | Work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`: override-floor correction in `.github/copilot-instructions.md`, `.github/agents/security-reviewer.agent.md`, `.github/skills/beryllium-security-review/SKILL.md`, and `tests/validate-agent.sh`; the unchanged explicit `claude-fable-5.1` allowance is retained, while `PMD-20260930-005` / `PMR-110` supersedes only PMR-109's keep-`max` / `long_context` Codex wording. The return commit contains `HANDOFF.md` only and its exact SHA is returned separately | Shared combined validation with `PMR-110`: `bash ./tests/validate-agent.sh` `396 passed, 0 failed`; `bash ./scripts/update-index.sh --check` exit 0; `git diff --check` exit 0; agent work-commit request was refused before any Git command, then the responsible human created the exact work commit | `main`; work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`; handoff-only return commit containing this row; two local commits ahead of unfetched private `origin/main` at `2e8d2054840af35ba6d64a00546ee99806a88dfb`; not pushed; no remote backup; launcher session active and reservation held until exit | Verify the returned work and return commits, record the stated no-backup and active-reservation state, and close `PMR-109` independently |
| `PMR-110` | `completed` | Work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`: exact Codex `xhigh` / `default` policy, non-Codex `max` / `high` floor, and no-fallback enforcement in `.github/copilot-instructions.md`, all four `.github/agents/*.agent.md` profiles, `.github/skills/beryllium-security-review/SKILL.md`, `tests/validate-agent.sh`, `README.md`, and `AGENT-INTERFACE.md`. The return commit contains `HANDOFF.md` only and its exact SHA is returned separately | Shared combined validation with `PMR-109`: `bash ./tests/validate-agent.sh` `396 passed, 0 failed`; `bash ./scripts/update-index.sh --check` exit 0; `git diff --check` exit 0; agent work-commit request was refused before any Git command, then the responsible human created the exact work commit | `main`; work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`; handoff-only return commit containing this row; two local commits ahead of unfetched private `origin/main` at `2e8d2054840af35ba6d64a00546ee99806a88dfb`; not pushed; no remote backup; launcher session active and reservation held until exit | Verify the returned work and return commits, record the stated no-backup and active-reservation state, and close `PMR-110` independently |
| `PMR-118` | `completed` | The single `PMR-138` replacement commit containing this row, with parent `c2edac70afdfe5b0bb90e237487cd168fb91e900`; exact SHA returned separately. It replaces the owner commit that first held this return, which is no longer on `main` and is identified only in private parent records. Startup-anchor wording in `.github/copilot-instructions.md`, `.github/agents/security-reviewer.agent.md`, `.github/agents/security-evidence.agent.md`, `.github/agents/security-research.agent.md`, `.github/agents/security-finding-review.agent.md`, `.github/skills/beryllium-security-review/SKILL.md`, `AGENT-INTERFACE.md`, and `README.md`, assertions in `tests/validate-agent.sh`, and this `HANDOFF.md`: before any target, sibling, component, or Project Manager tasking resolution the orchestrator reads current `workspace://SOT.md`, runs allowlisted `bash ./scripts/readonly-inspect.sh hash-file workspace SOT.md` (regular non-symlinked file required), and compares the printed `sha256` with the `Global startup/status SHA-256` pinned in `workspace://project-manager/outbox/tasking/security-reviewer.md`, stopping on an absent, unreadable, symlinked, or drifted anchor or an unavailable digest; each write-disabled specialist reads the anchor and stops without the orchestrator's matching startup-anchor record. The exact resolver and no-fallback contract are unchanged; under `PMD-20261006-001` the Codex-preservation clause no longer applies. No new executable, script change, engagement, package, or target execution | Original return, shared with `PMR-123`: `bash ./tests/validate-agent.sh` `483 passed, 0 failed`; `bash ./scripts/update-index.sh --check` exit 0; `git diff --check` exit 0; live `bash ./scripts/readonly-inspect.sh hash-file workspace SOT.md` printed `7fa17e4eaf4fb37096f4bd2aef853e399b025e4d3271d88db5cee6ac02284552`, equal to the pinned tasking digest; no known failures. Replacement tree: as recorded in the `PMR-138` row | `main`; the replacement commit containing this row is one ahead of `c2edac7` and, until the `PMR-138` force push with lease, diverges from the remote-tracking `origin/main`, which holds the replaced commits; the original return came from a direct human-started session with no launcher reservation, and the responsible human confirmed no other writer on 2026-11-08 before the replacement; the responsible human creates the replacement commit | After `PMR-138` closes, verify the replacement commit and close `PMR-118` independently |
| `PMR-123` | `completed` | Same `PMR-138` replacement commit containing this row, with parent `c2edac70afdfe5b0bb90e237487cd168fb91e900`; exact SHA returned separately; it replaces the owner commit that first held this return. All four `.github/agents/*.agent.md` profiles move from `gpt-5.3-codex` to `model: claude-opus-5.5` with invocation defaults reasoning effort `max` and context tier `long_context`, and the orchestrator passes that exact triple to every specialist; the `PMD-20260930-005` Codex-exception wording, the non-Codex `high` / `xhigh` floor and override wording, and the explicit `claude-fable-5.1` allowance are removed from those profiles, `.github/copilot-instructions.md`, `.github/skills/beryllium-security-review/SKILL.md`, `AGENT-INTERFACE.md`, and `README.md`, which now record that a security review runs only on explicit responsible-human request, on that same model, and is not standard practice; `tests/validate-agent.sh` asserts the triple and that wording and refutes the retired values; this `HANDOFF.md` is updated. Publication-safe provenance, earlier returns, and recorded model provenance are unchanged; no `reviews/SR-*` or `syntheses/SRS-*` package exists | Shared with `PMR-118`, as recorded in that row | `main`; same commit, divergence, no-push, and session state as the `PMR-118` row | After `PMR-138` closes, verify the replacement commit and close `PMR-123` independently; `PMR-111` is superseded by `PMR-138`; no push authority is requested |
| `PMR-138` | `completed` | The single replacement commit containing this row, with parent `c2edac70afdfe5b0bb90e237487cd168fb91e900`, replacing the two later commits on public `main`; exact SHA returned separately. It carries forward the earlier publication-safety maintenance and the `PMR-118` / `PMR-123` changes with no embedded denylisted identifier in any form: `scripts/lint-review-manifest.mjs` drops the identifier-specific manifest check and keeps the `unlisted` qualification rule; `tests/test-review-manifest.mjs` drops the identifier test and keeps the `unlisted` tests; `scripts/validate-security-review.sh` delegates the package scan to the installed gate's `scan-tree` (a `note` and skip without it, fail closed when an installed gate cannot scan); `tests/validate-agent.sh` delegates the publishable-file scan to the installed gate and tests the delegation with a synthetic term; `README.md` documents the optional gate; this `HANDOFF.md` names the replacement commit and keeps replaced commit identifiers out of public text. No file is added or deleted | `bash ./tests/validate-agent.sh`: `487 passed, 0 failed`, including the installed gate's `scan-tree` `PASS` over 124 publishable repository files and the synthetic-term delegation tests; `bash ./scripts/update-index.sh --check`: exit 0; this session ran no Git, so `git diff --check` and the gate audit of the repaired history are responsible-human steps; no known failures | `main`; replacement commit on `c2edac7`, diverged from the remote-tracking `origin/main` (which holds the replaced commits) until the force push with lease; the agent did not push, fetch, or change visibility; no remote backup of the replacement commit; both visibility changes follow `PMD-20261108-002` and are human-run; this launcher-started owner session stays active for `PMR-141`, and its reservation is released when the responsible human ends it | After the responsible human's gate audit, force push with lease, and `git fetch --prune --tags origin`, run `audit --all-refs` of this clone and close `PMR-138` when it passes; then verify `PMR-118` and `PMR-123` against this commit; after any return to public visibility, confirm the live view with `audit --remote origin` |
