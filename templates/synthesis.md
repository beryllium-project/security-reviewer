<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-review synthesis: @@TITLE@@

Package ID: `@@PACKAGE_ID@@`
Title: @@TITLE@@
Created: @@CREATED@@
Status: `Draft`
Distribution: `private`
Latest synthesis iteration: `SYNTHESIS-ITERATION-001`

A synthesis reads every input review package, normalizes findings by mechanism
and credible failure mode, deduplicates while retaining every source finding
ID, resolves each disposition from current target evidence, separates defects,
evidence gaps, recommendations, process gaps, already-addressed items,
unsupported claims, and fixed-scope non-goals, and prefers bounded changes.
Owner-side completion is recorded only by the owner; this package records
dispositions and recommendations, never fixes. Every owner-facing action is
queued as an `SRQ-NNN` `owner-action` row for the Project Manager.

## Method

1. Read all input packages in full at their recorded target commits.
2. Normalize findings by mechanism and credible failure mode.
3. Deduplicate while retaining every source finding ID in
   `disposition-ledger.md`.
4. Resolve each disposition from current target evidence.
5. Separate defects, evidence gaps, recommendations, process gaps,
   already-addressed items, unsupported claims, and fixed-scope non-goals.
6. Prefer bounded changes with a named principal dependency.

## Canonical actions

Action IDs are `REV-P{0..3}-NN`; Priority is `P0`, `P1`, `P2`, or `P3` and
matches the action ID. Disposition is `Confirmed`, `Partially confirmed`,
`Recommendation`, `Already addressed`, `Rejected-unsupported`, or
`Fixed-scope non-goal`.

| Action | Priority | Title | Disposition | Principal dependency | Owner checkpoint |
| --- | --- | --- | --- | --- | --- |
| None | Not recorded | No canonical action has been recorded. | Not recorded | None | None |

## Evidence corrections

Conservative corrections to input-package evidence, each citing a
`@@PACKAGE_ID@@-E####` row.

| Input finding | Correction | Evidence IDs |
| --- | --- | --- |
| None | None | None |

## Closed dispositions

| Source finding | Disposition | Rationale | Evidence IDs |
| --- | --- | --- | --- |
| None | Not recorded | No disposition has been closed. | None |

## Responsible-human checkpoints

- No checkpoint has been recorded. The synthesis never grants or infers
  implementation authorization, acceptance, review approval, risk acceptance,
  sign-off, licensing, publication, or release.
