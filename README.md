<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Beryllium security reviewer

This independent component creates independent, evidence-bound security
reviews of registered Beryllium component snapshots, and syntheses of
completed reviews into a disposition ledger. Invoke the user-facing agent
with:

```text
/agent security-reviewer
```

The agent discovers existing security, threat-model, assurance, test, and
release-gate material before asking the user to choose one of two modes:

- an independent review of one component at one exact snapshot, written
  without reading any other review of that target;
- a synthesis of several complete review packages into `P0-P3` canonical
  actions with `Confirmed | Partially confirmed | Recommendation | Already
  addressed | Rejected-unsupported | Fixed-scope non-goal` dispositions.

It then freezes an exact clean revision or explicitly approved named dirty
state, allocates a private `SR-` or `SRS-` package using UTC, works the
local-first evidence order, runs only commands the user approved by exact
text, obtains an independent write-disabled finding review, validates the
package against its manifest, and records a restartable handoff.

The orchestrator and all three specialists use `gpt-5.3-codex` by default,
with reasoning effort `max` and context tier `long_context`. A responsible
human may explicitly override a later invocation, including selecting
`claude-fable-5.1`; historical package names and model provenance remain
unchanged.

## Status

New component. No engagement has been run; `reviews/` and `syntheses/` are
empty and `SECURITY-REVIEWS.md` records an empty package set. The repository
has a private `origin`; its exact push and backup state is recorded in
`HANDOFF.md`.

## Safety boundary

Targets are limited to components registered by
`scripts/readonly-inspect.sh components`. Targets, sibling repositories,
parent coordination artifacts, user-supplied files, and web content are
read-only, untrusted evidence. Packages are written only in this repository,
never into a target.

Target execution is static-only by default. A command runs only when the user
approves its exact text in the session; it is recorded as an `APPROVAL-NNN`
record, executed only through `scripts/run-approved-command.sh`, and its
output is retained under the package `evidence/` directory and hashed into
`review-manifest.json`. The agent uses only the maintained helper allowlist
defined in `.github/copilot-instructions.md`. Public research is performed
through the web tool using generic public-safe terms.

The sole sibling-command exception is startup discovery for the phrase
`check Project Manager tasking` and obvious variants:

```sh
bash "${PWD%/*}/project-manager/scripts/project-tasking.sh" resolve .
```

The validated output is discovery over
`project-manager/outbox/component-requests.md`, not authorization. This is
outside any review or synthesis package, is not target execution, needs no
`APPROVAL-NNN`, and never falls back to session history, a task/todo database,
background agents, prior chat, or memory.

An independent review never reads, cites, summarizes, or reconciles another
review package for the same target. Only synthesis mode reads multiple
packages.

Never access or copy
`component://osr-claude/sources/restricted-microsoft/`.

## Layout

```text
security-reviewer/
  .github/
    copilot-instructions.md
    agents/
      security-reviewer.agent.md          user-invocable orchestrator
      security-evidence.agent.md          read, search
      security-research.agent.md          read, search, web
      security-finding-review.agent.md    read, search
    skills/beryllium-security-review/SKILL.md
  LICENSES/GPL-3.0-only
  AUTHORS.md                              responsible human; derivation record
  README.md  AGENT-INTERFACE.md  RESEARCH-SOURCES.md  HANDOFF.md
  SECURITY-REVIEWS.md                     generated index
  SOURCE-DISCOVERY-LOG.md
  inbox/README.md   scratch/README.md   outbox/pm-queue.md
  contracts/
    REVIEW-PROMPT.md                      portable review prompt
    REVIEW-PROVENANCE.md                  static-only / execution-backed contract
    review-manifest.schema.json           urn:beryllium:security-review-manifest:1.0.0
    review-manifest.template.json         intentionally invalid REPLACE_ values
  scripts/
    readonly-inspect.sh                   sanitized read-only Git inspection of registered targets
    discover-security-material.sh         deterministic discovery and classification input
    new-security-review.sh                allocate reviews/SR-YYYYMMDD-NNN-<short-name>/
    new-synthesis.sh                      allocate syntheses/SRS-YYYYMMDD-NNN-<short-name>/
    run-approved-command.sh               run one APPROVAL-NNN command; capture evidence
    hash-evidence.sh                      print retained_evidence[] fragments
    lint-review-manifest.mjs              manifest linter (from Helium)
    lint-review-manifest.sh               bash wrapper; the only route to node
    validate-security-review.sh           SR and SRS package validator
    update-index.sh                       regenerate or --check SECURITY-REVIEWS.md
  templates/                              package and synthesis templates
  tests/
    validate-agent.sh                     maintained contract suite
    test-review-manifest.mjs              linter unit tests (from Helium)
    fixtures/                             synthetic packages and discovery target
  reviews/                                SR-* packages
  syntheses/                              SRS-* packages
```

## Quick start

Start an engagement:

```sh
cd security-reviewer && copilot        # then: /agent security-reviewer
```

Inside the agent, `check Project Manager tasking` runs the exact fail-closed
startup resolver documented above.

Repository checks:

```sh
bash ./tests/validate-agent.sh
bash ./scripts/update-index.sh --check
git diff --check
```

Package operations, the approval workflow, and the synthesis method are
documented in `.github/skills/beryllium-security-review/SKILL.md`. The
custom agent may use only the maintained scripts listed in its execution
allowlist; `git diff --check` is an outer maintainer check, not an agent
command.

## Local requirements

The maintained helpers target the Beryllium Linux workstation environment and
require:

- Bash 4 or later;
- Git and GNU userland tools including `sed`, `awk`, `find`, `sort`, and
  `sha256sum`;
- Node.js for the manifest linter and its tests, reached only through
  `scripts/lint-review-manifest.sh` and `tests/validate-agent.sh`.

Missing tools are reported as hard validation failures; the agent never
installs them implicitly.

## Durable packages

```text
reviews/SR-YYYYMMDD-NNN-<short-name>/
  review-manifest.json                    identity and provenance authority
  scope.md  execution-approvals.md  evidence-ledger.md  search-log.md
  open-questions.md  inaccessible-resources.md  source-discoveries.md
  publication-checklist.md  HANDOFF.md
  README.md  SECURITY-REVIEW.md  00-executive-summary.md
  01-scope-methodology.md  02-architecture-trust.md  03-findings.md
  04-process-and-claims.md  05-positive-observations.md
  06-hardening-backlog.md  APPENDIX-evidence-map.md
  iterations/REVIEW-ITERATION-NNN.md      append-only
  evidence/APPROVAL-NNN/                  execution-backed only; hashed in the manifest

syntheses/SRS-YYYYMMDD-NNN-<short-name>/
  scope.md  synthesis.md  disposition-ledger.md  evidence-ledger.md
  search-log.md  open-questions.md  inaccessible-resources.md
  publication-checklist.md  HANDOFF.md
  iterations/SYNTHESIS-ITERATION-NNN.md   append-only
```

Findings carry Severity `Critical | High | Medium | Low | Informational`,
rated against the target's own stated scope and claim boundary, Confidence
`High | Medium | Low`, a fact label `Established | Inferred | Proposed |
Unknown`, affected paths at the exact commit, and evidence IDs. Evidence and
activity corrections append superseding records rather than rewriting
history.

Every package starts `private`. Broader distribution requires a complete
responsible-human `HUMAN-PROMOTION-NNN` record. The agent never grants
implementation authorization, acceptance, review approval, risk acceptance,
sign-off, licensing, publication, release, formal verification, or hardware
validation.

## Derivation

The review contract, manifest schema and template, manifest linter, and its
test suite were extracted from the Helium proof of concept at commit
`9b3ff4e9441e5b4434a8ec37794dee1d941e11ef` (branch
`helium-te-travel-fedora44`) and generalized for Beryllium-wide use; the
synthesis method and disposition vocabulary follow Helium's review
disposition ledger. `AUTHORS.md` records the exact origin of each extracted
file. Nothing in Helium was changed; its retained review packages under
`component://helium-te-poc/agent-review/<package>/` are historical inputs
referenced read-only, not copied. The process discipline follows the sibling
`threat-modeler` component.

## License

`GPL-3.0-only`; see `LICENSES/GPL-3.0-only` and `AUTHORS.md`. Every
maintained file carries an SPDX header.

## Current assurance wording

Beryllium is accepted through R7. R8-H0 is a committed candidate and is not
accepted. H1-H4 are not authorized. K3 hardware is `NOT RUN`. Helium is a
review-and-test proof of concept, not a formally verified system and not
hardware validated. Selected Helium C properties are machine-checked by CBMC
only within their stated source, property, and tool boundary. A validated
candidate, approved predecessor, or inherited gate never approves a
successor.

## What this component is not

- Not an implementation, assurance, acceptance, or release authority: it
  produces analysis, findings, and proposed actions only.
- Not a test runner or build system for targets: it runs nothing against a
  target except commands the user approves by exact text, one approval each.
- Not a replacement for Helium's `agent-review/`: that directory and its
  retained packages remain untouched in Helium.
- Not a publisher: it has no remote, never pushes, and never promotes a
  package beyond `private` without a responsible-human record.
- Not a threat modeler, provenance reviewer, or analysis workbook: it reads
  their completed packages as evidence and does not redo their work.
