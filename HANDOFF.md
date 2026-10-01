<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-reviewer handoff

**Last updated:** 2026-10-01

## Overall position

The component was created on 2026-09-06 by extracting and generalizing the
Helium proof-of-concept review contract at commit
`9b3ff4e9441e5b4434a8ec37794dee1d941e11ef` (branch
`helium-te-travel-fedora44`); see `AUTHORS.md` for the per-file derivation
record. Helium was read only and not changed.

At owner-session start, this independent repository was clean on `main` at
`2e8d2054840af35ba6d64a00546ee99806a88dfb`, with the last-fetched
`origin/main` at the same commit and local ahead/behind `0/0`. The responsible
human created work commit
`2bb4c989bbe9b57f870e6f653ed3732e742b11f9`, whose parent is the synchronized
base and whose nine paths contain the `PMR-109` and `PMR-110` policy and test
changes. The final combined tree, including this handoff, observed
`396 passed, 0 failed`, a current generated index, and a clean whitespace
diff.

The execution layer first refused the agent-requested work commit before any
Git command ran because it enforces this component's direct-Git prohibition;
the responsible human then created the work commit manually. This
`HANDOFF.md` refresh is the sole remaining path and is prepared as the
handoff-only return commit; its exact SHA must be returned separately because
a commit cannot contain its own final hash. No push or fetch occurred. The
last-fetched private `origin/main` remains at the base, so neither local commit
has remote backup. State is recorded from the launcher-backed owner session
started at `2026-09-30T23:26:53Z` (`2026-10-01` local): the session is active,
its component reservation is held until Copilot exits, and release has not
been observed. No engagement has been run: `reviews/` and `syntheses/` are
empty and `SECURITY-REVIEWS.md` records an empty package set.

## What exists

- one user-facing `security-reviewer` orchestrator
  (`.github/agents/security-reviewer.agent.md`) and three write-disabled
  specialists (`security-evidence`, `security-research`,
  `security-finding-review`), all pinned to `gpt-5.3-codex` with exact
  reasoning effort `xhigh` and context tier `default`; Codex effort and
  context are not overridable, explicit non-Codex selections retain the
  project-wide `max` default and `high` minimum with only `high`, `xhigh`, or
  `max` permitted, and unavailable selected values stop without silent
  fallback;
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
For the current combined `PMR-109` / `PMR-110` work and handoff tree, this
session observed `bash ./tests/validate-agent.sh`: `396 passed, 0 failed`;
`bash ./scripts/update-index.sh --check`: exit 0; and `git diff --check`:
exit 0.

## Open items

- **Handoff-only return commit remains.** The responsible human created work
  commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`; `HANDOFF.md` must now be
  committed alone so its exact return SHA can be reported. The agent must not
  retry or bypass the direct-Git refusal.
- **Remaining sibling target registration is owner-side.** Threat-modeler
  registered `security-reviewer` at owner commit `c4126b6`; the
  analysis-workbook registration remains requested as `PMR-050`.
- **No backup exists for this owner-session work.** Push and backup remain
  responsible-human gates and are not authorized by `PMR-109` or `PMR-110`.
- **Reservation release is not yet observable.** This launcher-backed session
  remains active and retains its component reservation until Copilot exits.
- **No first engagement.** The workflow has been exercised only against
  synthetic fixtures by the maintained suite, not against a real target.

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

## Restartable next action

Resolve `OWNER-GATE-002` by creating the `HANDOFF.md`-only return commit:

```sh
git diff --check
git add -- HANDOFF.md
git diff --cached --check
test "$(git diff --cached --name-only)" = HANDOFF.md
git commit \
  -m 'PMR-109 PMR-110: record owner return' \
  -m 'Record the exact work commit, validation, backup, active-session, and reservation state.' \
  -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
git rev-parse HEAD
git status --short --branch
```

Return the exact SHA and status output. Do not push, fetch, begin an
engagement, or ask the Project Manager to verify the return before that SHA is
known.

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

## Project Manager return

| Related IDs | Result | Evidence | Validation | Repository state | Requested Project Manager action |
| --- | --- | --- | --- | --- | --- |
| `PMR-062` | `completed` | Single owner commit containing this row, with parent `79c664f6130ec1e740282e6dd0ebe6fe6d136ea1`; `.github/agents/security-reviewer.agent.md`, `.github/agents/security-evidence.agent.md`, `.github/agents/security-research.agent.md`, `.github/agents/security-finding-review.agent.md`, `.github/copilot-instructions.md`, `.github/skills/beryllium-security-review/SKILL.md`, `tests/validate-agent.sh` | `bash ./tests/validate-agent.sh`: `319 passed, 0 failed`; `bash ./scripts/update-index.sh --check`: exit 0 | `main`; fifth local commit ahead of private `origin/main` at `9ca5071b450eae39f63f7e31f61ad3e7009070e0`; not pushed; no remote backup of this commit; exact post-amend SHA returned separately | Verify the returned owner commit and close `PMR-062` independently |
| `PMR-065` | `completed` | Same single owner commit containing this row, with parent `79c664f6130ec1e740282e6dd0ebe6fe6d136ea1`; `.github/agents/security-reviewer.agent.md`, `.github/copilot-instructions.md`, `.github/skills/beryllium-security-review/SKILL.md`, `AGENT-INTERFACE.md`, `README.md`, `HANDOFF.md`, `tests/validate-agent.sh` | `bash ./tests/validate-agent.sh`: `319 passed, 0 failed`; `bash ./scripts/update-index.sh --check`: exit 0 | `main`; fifth local commit ahead of private `origin/main` at `9ca5071b450eae39f63f7e31f61ad3e7009070e0`; not pushed; no remote backup of this commit; exact post-amend SHA returned separately | Verify the returned owner commit and close `PMR-065` independently |
| `PMR-074` | `completed` | Single owner commit containing this row, with parent `f2051a4b70ab211a943fe3e2fa38221f6df02d44`; `.github/agents/security-reviewer.agent.md`, `.github/agents/security-evidence.agent.md`, `.github/agents/security-research.agent.md`, `.github/agents/security-finding-review.agent.md`, `.github/copilot-instructions.md`, `.github/skills/beryllium-security-review/SKILL.md`, `tests/validate-agent.sh`, `AGENT-INTERFACE.md`, `README.md`, `HANDOFF.md` | `bash ./tests/validate-agent.sh`: `321 passed, 0 failed`; `bash ./scripts/update-index.sh --check`: exit 0; `git diff --check`: exit 0 | `main`; one local commit ahead of private `origin/main` at `f2051a4b70ab211a943fe3e2fa38221f6df02d44`; not pushed; no remote backup of this commit; exact SHA returned separately | Verify the returned owner commit and close `PMR-074` independently |
| `PMR-109` | `completed` | Work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`: override-floor correction in `.github/copilot-instructions.md`, `.github/agents/security-reviewer.agent.md`, `.github/skills/beryllium-security-review/SKILL.md`, and `tests/validate-agent.sh`; the unchanged explicit `claude-fable-5.1` allowance is retained, while `PMD-20260930-005` / `PMR-110` supersedes only PMR-109's keep-`max` / `long_context` Codex wording. The return commit contains `HANDOFF.md` only and its exact SHA is returned separately | Shared combined validation with `PMR-110`: `bash ./tests/validate-agent.sh` `396 passed, 0 failed`; `bash ./scripts/update-index.sh --check` exit 0; `git diff --check` exit 0; agent work-commit request was refused before any Git command, then the responsible human created the exact work commit | `main`; work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`; handoff-only return commit containing this row; two local commits ahead of unfetched private `origin/main` at `2e8d2054840af35ba6d64a00546ee99806a88dfb`; not pushed; no remote backup; launcher session active and reservation held until exit | Verify the returned work and return commits, record the stated no-backup and active-reservation state, and close `PMR-109` independently |
| `PMR-110` | `completed` | Work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`: exact Codex `xhigh` / `default` policy, non-Codex `max` / `high` floor, and no-fallback enforcement in `.github/copilot-instructions.md`, all four `.github/agents/*.agent.md` profiles, `.github/skills/beryllium-security-review/SKILL.md`, `tests/validate-agent.sh`, `README.md`, and `AGENT-INTERFACE.md`. The return commit contains `HANDOFF.md` only and its exact SHA is returned separately | Shared combined validation with `PMR-109`: `bash ./tests/validate-agent.sh` `396 passed, 0 failed`; `bash ./scripts/update-index.sh --check` exit 0; `git diff --check` exit 0; agent work-commit request was refused before any Git command, then the responsible human created the exact work commit | `main`; work commit `2bb4c989bbe9b57f870e6f653ed3732e742b11f9`; handoff-only return commit containing this row; two local commits ahead of unfetched private `origin/main` at `2e8d2054840af35ba6d64a00546ee99806a88dfb`; not pushed; no remote backup; launcher session active and reservation held until exit | Verify the returned work and return commits, record the stated no-backup and active-reservation state, and close `PMR-110` independently |
