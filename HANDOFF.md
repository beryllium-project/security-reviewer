<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-reviewer handoff

**Last updated:** 2026-09-12

## Overall position

The component was created on 2026-09-06 by extracting and generalizing the
Helium proof-of-concept review contract at commit
`9b3ff4e9441e5b4434a8ec37794dee1d941e11ef` (branch
`helium-te-travel-fedora44`); see `AUTHORS.md` for the per-file derivation
record. Helium was read only and not changed.

The repository is an independent Git repository on `main`. Before the
2026-09-12 Project Manager carry, local `main` at `9ca5071` was synchronized
with `origin/main`; the owner created that private remote and pushed it on
2026-09-06 (`PMR-021`). Current `main` is the carried coordination commit
`c13c36e`, one commit ahead of `origin/main` pending owner review and push.
This is a private backup state, not publication. No engagement has been run:
`reviews/` and `syntheses/` are empty and `SECURITY-REVIEWS.md` records an
empty package set.

## What exists

- one user-facing `security-reviewer` orchestrator
  (`.github/agents/security-reviewer.agent.md`) and three write-disabled
  specialists (`security-evidence`, `security-research`,
  `security-finding-review`);
- the `beryllium-security-review` skill
  (`.github/skills/beryllium-security-review/SKILL.md`) with guided intake,
  exact-revision freeze, deterministic discovery, the `Independent review |
  Synthesis` mode gate, the `APPROVAL-NNN` approved-execution workflow, the
  Helium report set, the synthesis method, and the `Human review target`
  reply contract;
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
human should re-run the suite before relying on it.

## Open items

- **Sibling target registration is owner-side.** Registering
  `security-reviewer` as a target in sibling `readonly-inspect.sh` lists is
  a change to those owners' repositories; it remains requested as `PMR-022`
  through the Project Manager, not made here.
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

From the `security-reviewer/` repository, run:

```sh
bash ./tests/validate-agent.sh
```

If it passes, start a fresh Copilot CLI session in this directory, run
`/agent security-reviewer`, choose the registered target `helium-te-poc` at
its exact clean commit reported by `bash ./scripts/readonly-inspect.sh state
helium-te-poc`, decline any session execution set (static-only), and verify
that the agent presents discovery candidates before it offers the
`Independent review | Synthesis | Edit scope | Cancel` gate. Do not begin a
substantive package unless that engagement is intended.

## Coordination update

The Project Manager carried only the registration, backup, and source-pointer
wording above under `PMR-030`, `PMR-031`, and class 3 of
`PMD-20260904-003`. It did not run an engagement, modify review content, grant
a gate, or push this component.
