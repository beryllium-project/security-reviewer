<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-review synthesis: Synthetic synthesis fixture

Package ID: `SRS-20000101-001-fixture-synthesis`
Title: Synthetic synthesis fixture
Created: 2000-01-01
Status: `Complete`
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
| REV-P2-01 | `P2` | Add an alias-identifier test or narrow the complete-mediation claim | `Confirmed` | Owner test harness | Owner decides between test and claim narrowing |

## Evidence corrections

Conservative corrections to input-package evidence, each citing a
`SRS-20000101-001-fixture-synthesis-E####` row.

| Input finding | Correction | Evidence IDs |
| --- | --- | --- |
| None | No correction required. | None |

## Closed dispositions

| Source finding | Disposition | Rationale | Evidence IDs |
| --- | --- | --- | --- |
| SR-20000101-001-fixture-review FINDING-001 | `Confirmed` | The input evidence (SR-20000101-001-fixture-review-E0002) still shows no alias-identifier test at `1111111111111111111111111111111111111111`. | SRS-20000101-001-fixture-synthesis-E0001 |

## Responsible-human checkpoints

- Owner decision on REV-P2-01 is queued as an `SRQ-NNN` `owner-action` row. The synthesis never grants or infers
  implementation authorization, acceptance, review approval, risk acceptance,
  sign-off, licensing, publication, or release.
