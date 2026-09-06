<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-review synthesis scope

Package ID: `SRS-20000101-001-fixture-synthesis`
Title: Synthetic synthesis fixture
Created: 2000-01-01
Status: `Complete`
Phase: `Complete`
Mode: `synthesis`
Distribution: `private`
Latest synthesis iteration: `SYNTHESIS-ITERATION-001`

## Input packages

Inputs are complete `SR-` review packages. Location is a path relative to the
repository root. Target commit is copied from each input manifest; when inputs
differ in commit, `synthesis.md` must carry a `## Commit correspondence`
section.

| Package ID | Location | Target commit | Status |
| --- | --- | --- | --- |
| SR-20000101-001-fixture-review | `tests/fixtures/valid-review/SR-20000101-001-fixture-review/` | `1111111111111111111111111111111111111111` | `Complete` |

## Effective scope

- Target component: `component://helium-te-poc` (synthetic fixture).
- Synthesis question: Which fixture findings are confirmed against current target evidence?
- Exclusions: Everything outside the input package.
- Public research: not permitted.
- Intended distribution: private.
- Write boundary: This package and repository only; the target and the input
  packages are never written.
- Known limitations: Synthetic fixture with one input package.

## Confirmation

- Discovery-mode choice: Synthesis.
- Scope confirmation: Confirmed.
- Responsible human: Synthetic fixture actor.
- Confirmation date: 2000-01-01.

## Activity

| Activity ID | Date | Actor | Action | Evidence IDs | Notes |
| --- | --- | --- | --- | --- | --- |
| ACTIVITY-001 | 2000-01-01 | Security-reviewer | Allocated a private synthesis package. | None | Synthetic fixture. |
| ACTIVITY-002 | 2000-01-01 | Security-reviewer | Completed the synthesis of one input package. | SRS-20000101-001-fixture-synthesis-E0001 | Synthetic fixture. |
