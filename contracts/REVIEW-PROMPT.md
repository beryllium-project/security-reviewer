<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Independent security review prompt

Use this prompt with any model or agent to produce comparable, independent
security reviews of one registered Beryllium component snapshot. The review
target is identified by three facts that the responsible human fixes before
the review starts and that every report must repeat exactly:

- the **target component**, named by its registered component name and
  logical locator `component://<name>`;
- the **exact commit** (full lowercase 40-hex) of the reviewed snapshot,
  with its full `refs/heads/...` ref or detached state and its clean/dirty
  worktree state; and
- the target's own **stated scope and claim boundary**, taken from the
  target's handoff, README, security or limits, verification, and policy
  documents at that commit.

Review packages are written in this component only, under
`reviews/SR-YYYYMMDD-NNN-<short-name>/`, never in the target. Do not modify
any target file. Every package must include `review-manifest.json`
conforming to `contracts/review-manifest.schema.json` and
`contracts/REVIEW-PROVENANCE.md`.

## Prompt

Replace the bracketed placeholders before use. Keep everything else.

```text
perform a detailed and comprehensive security review of the component [TARGET COMPONENT NAME] (logical locator component://[TARGET COMPONENT NAME]) at exactly commit [FULL 40-HEX COMMIT]. do not modify any file of the target, and write output only to the new unique package directory reviews/[SR-YYYYMMDD-NNN-short-name]/ in the security-reviewer component. take your time and be thorough, and include review of the design, architecture, goals, processes etc.. include suggestions for improvement or correction as appropriate. rate severity against the target's own stated scope and claim boundary at that commit, not against goals the target does not claim.

do not use any other security review as input. under contracts/, read only the shared REVIEW-PROMPT.md, REVIEW-PROVENANCE.md, review-manifest.schema.json, and review-manifest.template.json process files. do not read, cite, summarize, or reconcile any other review package for this target, whether a local reviews/SR-* package or a package stored inside the target (for example an agent-review/ directory). base the review only on the target's sources, docs, tests, scripts, and tooling at the stated commit.

for this new package, create review-manifest.json from the shared template. make its package id match the package directory and record the registered component name and locator, the exact declared model id, run id, source commit, full branch ref or detached state, and dirty state. classify the review as static-only when no target-inspection, build, test, or execution command was attempted. otherwise classify it as execution-backed and record every such command attempted, including failures, its APPROVAL-NNN record, the referenced tool versions, exact exit results, and retained evidence files with sha256 hashes. run a command only when a responsible human approved that exact command in this session and only through scripts/run-approved-command.sh. do not claim execution that is not represented by consistent manifest metadata and retained evidence.
```

## Expected output layout

Choose the package id through `scripts/new-security-review.sh <short-name>
<title>`, which allocates a unique `SR-YYYYMMDD-NNN-<short-name>` and makes
it equal to `package.id` in the manifest. Keep the exact runtime identifiers
separately in `package.model_id` and `package.run_id`.

Report set (keep the names so packages stay comparable with each other and
with the retained historical Helium packages):

```text
reviews/<package-id>/
  review-manifest.json        # mandatory for every package
  execution-approvals.md      # APPROVAL-NNN records, or "No approvals recorded."
  evidence/                   # mandatory only for execution-backed packages
  README.md
  SECURITY-REVIEW.md          # single-document rollup
  00-executive-summary.md
  01-scope-methodology.md
  02-architecture-trust.md
  03-findings.md
  04-process-and-claims.md
  05-positive-observations.md
  06-hardening-backlog.md
  APPENDIX-evidence-map.md
```

The component's process files (`scope.md`, `evidence-ledger.md`,
`search-log.md`, `open-questions.md`, `inaccessible-resources.md`,
`source-discoveries.md`, `publication-checklist.md`, `HANDOFF.md`,
`iterations/`) complete the package; the scaffolder creates them from
`templates/`.

## Constraints for reviewers

- Read-only against the target. Create files only under the new
  `reviews/<package-id>/` in this component. Never write, reset, clean, or
  reconcile the target worktree; if it is dirty, record that state exactly.
- **Independent review only:** do not use any other security review as
  input. The shared prompt, provenance contract, schema, and template are
  process inputs, not review findings. Do not read, cite, summarize, or
  reconcile any other review package for the same target. Base findings
  solely on the target's sources, docs, tests, scripts, and tooling at the
  exact commit.
- Start from the target's handoff, README, security or limits,
  verification, policy-alignment, and agent-instruction documents at that
  commit, then read the code and tests they point to.
- Cover design and architecture, trust boundaries, isolation mechanisms,
  privileged boundaries and state machines, tests and evidence tooling,
  build, evaluator, and CI paths, release and publication gates, and
  claim-boundary honesty.
- Prefer confirmed issues with exact paths written as
  `component://<name>/<path>` at the reviewed commit; mark severity
  (`Critical | High | Medium | Low | Informational`), confidence
  (`High | Medium | Low`), and fact label
  (`Established | Inferred | Proposed | Unknown`); every finding cites at
  least one evidence id from the package's evidence ledger.
- Treat `review-manifest.json` as the authoritative package identity and
  provenance record. Reports refer to it instead of repeating potentially
  divergent model, run, commit, branch, dirty-state, command, or evidence
  metadata.
- Follow the static-only, execution-backed, and approved-execution rules in
  `contracts/REVIEW-PROVENANCE.md`. Record failed command attempts and
  nonzero exits; never silently omit them.
- A finished package must pass
  `bash scripts/lint-review-manifest.sh reviews/<package-id>/review-manifest.json`
  and `bash scripts/validate-security-review.sh reviews/<package-id>`.

## Assurance wording

Preserve these boundaries verbatim wherever the topic arises. Beryllium is
accepted through R7; Beryllium R8-H0 is a committed candidate and is not
accepted; H1-H4 are not authorized; K3 hardware is `NOT RUN`. Helium is a
review-and-test proof of concept and is not formally verified or hardware
validated; selected Helium C properties may be described as machine-checked
by CBMC only within their stated source, property, and tool boundary. A
validated candidate, approved predecessor, or inherited gate never approves a
successor. A review never grants or infers implementation authorization,
acceptance, review approval, risk acceptance, sign-off, licensing,
publication, release, formal verification, or hardware validation; those
remain responsible-human gates.

## Layout reference only

Other packages under `reviews/`, and any review material stored inside the
target (for example `agent-review/<package>/` directories), may exist from
prior runs. Treat them as **out of scope for reading**. The shared process
files named above are the only exceptions. The report filenames are a layout
hint only; do not open other packages for findings or methodology.

## Derivation

Generalized from `component://helium-te-poc/agent-review/REVIEW-PROMPT.md` at
commit `9b3ff4e9441e5b4434a8ec37794dee1d941e11ef` (branch
`helium-te-travel-fedora44`). Helium-specific target wording, the in-target
`agent-review/<package-id>/` output location, and the retained-package
exemption were replaced by the registered-component target, the
`reviews/SR-*` package location, and the approved-execution rule; the review
discipline and report set are unchanged.
