<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Scope and methodology

Package ID: `@@PACKAGE_ID@@`
Title: @@TITLE@@
Created: @@CREATED@@
Status: `Draft`
Distribution: `private`

## Reviewed state

| Item | Value |
| --- | --- |
| Component | Not recorded |
| Logical locator | Not recorded |
| Commit | Not recorded |
| Branch | Not recorded |
| Worktree state | Not recorded |
| Review depth | Not recorded |
| Public research | Not recorded |

## Independence and constraints

- This package read only the target at the recorded commit, the shared
  `contracts/` files, and public sources listed in `search-log.md`.
- It did not read, cite, summarize, or reconcile any other review package for
  the same target.
- The target was never written. Commands ran only under `APPROVAL-NNN`
  records and are listed in `review-manifest.json`.

## Coverage

| Area | Coverage | Evidence IDs | Notes |
| --- | --- | --- | --- |
| Design and architecture | Not assessed | None | Review has not started. |
| Trust boundaries and isolation mechanisms | Not assessed | None | Review has not started. |
| Privileged boundaries and state machines | Not assessed | None | Review has not started. |
| Tests and evidence tooling | Not assessed | None | Review has not started. |
| Build, evaluator, and CI | Not assessed | None | Review has not started. |
| Release and publication gates | Not assessed | None | Review has not started. |
| Claim-boundary honesty | Not assessed | None | Review has not started. |

## Analysis techniques

Not recorded.

## Independent verification performed

None. A `static-only` package ran no target command.

## Confidence vocabulary

- Severity: `Critical`, `High`, `Medium`, `Low`, `Informational`, rated
  against the target's own stated scope and claim boundary.
- Confidence: `High`, `Medium`, `Low`.
- Fact label: `Established`, `Inferred`, `Proposed`, `Unknown`.

## Assurance wording

Beryllium is accepted through R7; Beryllium R8-H0 is a committed candidate and
is not accepted; H1-H4 are not authorized; K3 hardware is `NOT RUN`. Helium is
a review-and-test proof of concept and is not formally verified or hardware
validated; selected Helium C properties may be described as machine-checked by
CBMC only within their stated source, property, and tool boundary. A validated
candidate, approved predecessor, or inherited gate never approves a successor.
The agent never grants or infers implementation authorization, acceptance,
review approval, risk acceptance, sign-off, licensing, publication, release,
formal verification, or hardware validation.
