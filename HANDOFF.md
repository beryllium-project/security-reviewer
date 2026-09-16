<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-reviewer handoff

**Last updated:** 2026-09-16

## Overall position

The component was created on 2026-09-06 by extracting and generalizing the
Helium proof-of-concept review contract at commit
`9b3ff4e9441e5b4434a8ec37794dee1d941e11ef` (branch
`helium-te-travel-fedora44`); see `AUTHORS.md` for the per-file derivation
record. Helium was read only and not changed.

The repository is an independent Git repository on `main`. Before the
2026-09-16 `PMR-074` maintenance, local `main` was clean and synchronized
with the private `origin/main` at
`f2051a4b70ab211a943fe3e2fa38221f6df02d44`. The single owner commit
containing this handoff completes `PMR-074`, has that synchronized commit as
its parent, and leaves local `main` one commit ahead of `origin/main`. Its
exact SHA is returned to the Project Manager separately because a commit
cannot contain its own final hash. The owner commit has not been pushed and
therefore has no remote backup. No engagement has been run:
`reviews/` and `syntheses/` are empty and `SECURITY-REVIEWS.md` records an
empty package set.

## What exists

- one user-facing `security-reviewer` orchestrator
  (`.github/agents/security-reviewer.agent.md`) and three write-disabled
  specialists (`security-evidence`, `security-research`,
  `security-finding-review`), all pinned to `gpt-5.3-codex` with recorded
  reasoning effort `max` and context tier `long_context` defaults;
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

## Open items

- **Remaining sibling target registration is owner-side.** Threat-modeler
  registered `security-reviewer` at owner commit `c4126b6`; the
  analysis-workbook registration remains requested as `PMR-050`.
- **Private backup remains required.** The `PMR-074` owner commit remains
  local until the responsible human pushes `main` to the private `origin`.
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

Review the `PMR-074` owner commit returned with this handoff:

```sh
git status --short --branch
git show --stat --oneline HEAD
```

If accepted, back it up with `git push origin main`, then return the exact
commit and resulting backup state to the Project Manager so `PMR-074` can be
verified and closed. Do not begin a substantive review package as part of
this housekeeping request.

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
