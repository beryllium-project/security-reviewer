<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-review package provenance

This contract applies to every review package under `reviews/` in this
component. There is no exemption: a package without a manifest that passes
lint is incomplete and must not be marked `Complete`, published, or used as a
synthesis input.

The five retained Helium review packages
(`component://helium-te-poc/agent-review/<package>/`) are historical inputs
that predate this contract. They are referenced read-only by locator, never
copied into this component, and never given manifests, logs, hashes, or
inferred execution claims. Their absence of package-specific execution
provenance remains part of the historical record. Statements in them about
the reviewed Helium snapshot describe that snapshot, not Helium's current
state; Helium remains a review-and-test proof of concept that is not formally
verified or hardware validated.

## Required layout

Every package has a unique portable directory name and this mandatory
manifest:

```text
reviews/<package-id>/
  review-manifest.json
  execution-approvals.md     # APPROVAL-NNN records, or "No approvals recorded."
  evidence/                  # execution-backed packages only
    APPROVAL-NNN/            # one directory per executed approval
  ... review reports and process files ...
```

`<package-id>` matches `SR-YYYYMMDD-NNN-<short-name>` and equals
`package.id`. Start from `contracts/review-manifest.template.json`. The
completed file must conform to `contracts/review-manifest.schema.json` and
pass:

```sh
bash scripts/lint-review-manifest.sh reviews/<package-id>/review-manifest.json
```

The raw template intentionally contains invalid `REPLACE_...` values so it
cannot be mistaken for completed provenance.

The dependency-free linter first enforces the complete checked-in schema
subset: exact object shape, required fields, JSON types, constants/enums,
conditionals, array uniqueness/counts, numeric bounds, Unicode string lengths,
and patterns. It rejects any unsupported schema keyword rather than silently
ignoring it, then applies the cross-field, approval, and local-evidence
semantics below.

## Contract

`review-manifest.json` is the single authoritative machine-readable source for
package identity and provenance.

| Field | Required meaning |
| --- | --- |
| `package.id` | Exact package-directory basename, `SR-YYYYMMDD-NNN-<short-name>`. |
| `package.model_id` | Exact model identifier declared by the runtime or orchestrator. |
| `package.run_id` | Exact unique run identifier declared by the runtime or orchestrator. |
| `source.component` | Registered name of the reviewed component (lowercase portable identifier). The linter checks the form; the validator checks registration. |
| `source.locator` | Logical locator of the reviewed component, exactly `component://` followed by `source.component`. |
| `source.commit` | Full lowercase 40-hex reviewed Git commit. |
| `source.branch` | Full `refs/heads/...` ref, or `null` only when `source.detached` is true. |
| `source.detached` | Whether the reviewed checkout had detached `HEAD`. |
| `source.dirty` | Exact clean/dirty boolean for the reviewed checkout. |
| `source.dirty_detail` | `null` when clean; a nonempty qualification when dirty. |
| `execution.classification` | Mechanically derived `static-only` or `execution-backed`. |
| `execution.commands_attempted` | Every target-inspection, build, test, or execution command attempted, including failures. |
| `command_attempt.approval_id` | The `APPROVAL-NNN` record in `execution-approvals.md` that authorized this exact command; unique across `commands_attempted`. |
| `command_attempt.id` | The lowercase form of `approval_id` (`approval-001`). |
| `command_attempt.working_directory` | Logical locator of the directory the command ran in: `component://<name>` or `component://<name>/<subpath>`, identical to the approval record. |
| `execution.tool_versions` | Version string for every tool referenced by a command. |
| `execution.retained_evidence` | Package-relative evidence path under `evidence/APPROVAL-NNN/`, lowercase SHA-256, and producing command ID. |
| `qualifications` | Structured explanations for externally supplied or otherwise unverifiable metadata. |

Use the identifiers exactly as declared. If the runtime exposes no run ID, the
orchestrator must assign a unique one and record that fact in `qualifications`;
do not invent a vendor-issued identifier. A qualification never overrides a
schema or lint failure.

## Classification rules

### Static-only

Use `static-only` only when no command was attempted to inspect, build, test,
or execute the reviewed checkout. It requires:

- a nonempty `static_only_reason`;
- empty `commands_attempted`;
- empty `tool_versions`;
- empty `retained_evidence`; and
- no `executed` record in `execution-approvals.md`. When that file holds no
  approval record at all it carries the literal line
  `No approvals recorded.`; an `approved` or `withdrawn` record that was
  never executed is permitted and keeps the package static-only.

Source-reading APIs and this component's read-only inspection script
(`scripts/readonly-inspect.sh`) do not execute checkout commands and do not
by themselves make a package execution-backed. A static-only package must not
imply that tests, builds, emulation, or other commands ran.

### Execution-backed

Use `execution-backed` when at least one applicable command was attempted,
regardless of whether it succeeded. It requires:

- `static_only_reason` set to `null`;
- at least one command with its approval ID, exact command text, working
  directory, tool ID, and exit result;
- one declared version for every referenced tool (a `Tool version:
  unknown` approval requires a `qualifications` entry for
  `/execution/tool_versions`); and
- at least one regular retained evidence file for every command.

An exit result is exactly one of:

- `{"kind": "exited", "code": N}`;
- `{"kind": "signaled", "signal": "SIGNAME"}`; or
- `{"kind": "not-started", "reason": "..."}`.

Evidence paths must remain under the package's `evidence/APPROVAL-NNN/`
directory for the command's approval. The linter rejects missing files,
symbolic-link evidence, path traversal, duplicate identifiers or paths,
unknown references, evidence filed under another approval's directory, and
SHA-256 mismatches.

Administrative operations that only create, hash, lint, or validate the
completed package are not target execution evidence and must not be cited as
support for findings. This boundary prevents the manifest's own finalization
from creating recursive evidence requirements.

## Approved execution

The target is never executed by default. Each command attempt requires a
responsible human to approve that exact command by name in the session, and
the approval is recorded before anything runs.

- Every command attempt has an `APPROVAL-NNN` record in the package's
  `execution-approvals.md`, in exactly this form:

  ```text
  ### APPROVAL-001

  - Status: `approved`
  - Command: `./he test`
  - Working directory: `component://helium-te-poc`
  - Tool ID: `he`
  - Tool version: `unknown`
  - Expected target commit: `<40 hex>`
  - Approved by: responsible human
  - Approved on: `2026-09-06T18:00:00Z`
  - Quoted approval: "<exact user words from the session>"
  - Evidence directory: `evidence/APPROVAL-001/`
  ```

  `Status` is `approved` (recorded, not yet run), `executed`, or
  `withdrawn`. `Working directory` is `component://<name>` or
  `component://<name>/<subpath>`. `Tool ID` is a lowercase portable
  identifier. `Approved on` is UTC ISO-8601. Command text is taken verbatim
  between the backticks; commands must not contain backticks.
- Commands run only through `scripts/run-approved-command.sh <package-dir>
  <APPROVAL-NNN>`. The helper refuses to run when the record is absent,
  incomplete, or not `approved`; when the component is unregistered; when
  the target's observed commit differs from `Expected target commit`; when
  the target is dirty and the package `scope.md` snapshot row does not say
  `dirty (approved)`; or when the evidence directory already exists. It runs
  the command with a clean environment and no stdin, never writes the
  target, and exits nonzero only for its own refusals: a failing approved
  command is evidence, not a helper failure.
- Evidence lives under `evidence/APPROVAL-NNN/`: `stdout.log`,
  `stderr.log`, `exit-result.json`, and `run-record.json` (approval id,
  command, working directory, observed commit and dirty state, UTC start
  and finish, and the target's post-run dirty paths so that a command that
  modified the target is visible).
- After the run, the record's `Status` becomes `executed`, the manifest
  gains one `commands_attempted[]` entry with `approval_id` `APPROVAL-NNN`,
  `id` `approval-nnn` (the lowercase form), and identical `command` and
  `working_directory` text, plus the corresponding `tool_versions[]` entry.
  `approved` and `withdrawn` records have no manifest entry.
- Hashes come from `scripts/hash-evidence.sh <package-dir>`, which prints
  the `retained_evidence[]` fragments for every regular file under
  `evidence/` and refuses symbolic links.
- Approval records and manifests are attestations. The linter and validator
  check that they are mutually consistent; they do not prove that the
  quoted approval was given, that the command ran as recorded, or that the
  evidence is complete.

## Failure behavior and limits

Do not mark `Complete`, publish, integrate, or synthesize a package whose
manifest fails lint. Fix incorrect metadata; when an external fact cannot be
verified, retain the declared value and add a precise qualification. Never
convert absent execution evidence into an execution-backed claim.

The manifest is an attestation by the package producer. Schema validation,
cross-field checks, approval cross-checks, and local hash verification improve
traceability but do not prove that a command ran, that the declared model
produced the reports, or that orchestration was trustworthy. A passing lint
grants no human gate: implementation authorization, acceptance, review
approval, risk acceptance, sign-off, licensing, publication, and release
remain responsible-human decisions.

## Derivation

Generalized from `component://helium-te-poc/agent-review/REVIEW-PROVENANCE.md`
at commit `9b3ff4e9441e5b4434a8ec37794dee1d941e11ef` (branch
`helium-te-travel-fedora44`). The Helium retained-input exemption was
replaced by the read-only historical-input rule above; the package layout,
template, schema, and lint paths moved to this component; the field table
gained `source.component`, `source.locator`, `command_attempt.approval_id`,
and the working-directory locator; the "Approved execution" section is new.
The static-only and execution-backed classification rules are unchanged in
substance.
