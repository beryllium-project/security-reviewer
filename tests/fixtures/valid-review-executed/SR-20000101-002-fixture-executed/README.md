<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security review: Synthetic execution-backed review fixture

Package ID: `SR-20000101-002-fixture-executed`
Title: Synthetic execution-backed review fixture
Created: 2000-01-01
Status: `Complete`
Distribution: `private`

This package is an independent security review produced by the
`security-reviewer` component. It reviews exactly one target component at one
recorded commit and never modifies the target. Its provenance is declared in
`review-manifest.json` (see `contracts/REVIEW-PROVENANCE.md`); the manifest
records whether the review was `static-only` or `execution-backed`, and only
commands listed there were run.

## Contents

| File | Purpose |
| --- | --- |
| `SECURITY-REVIEW.md` | Single-document rollup of the whole review |
| `00-executive-summary.md` | Verdict, headline findings, claim-boundary assessment |
| `01-scope-methodology.md` | Reviewed state, independence, coverage, techniques |
| `02-architecture-trust.md` | Privilege and trust structure, boundaries, assumptions |
| `03-findings.md` | `FINDING-NNN` records rated against the target's stated scope |
| `04-process-and-claims.md` | Process, publication gate, and claim-boundary honesty |
| `05-positive-observations.md` | Strengths worth preserving |
| `06-hardening-backlog.md` | Prioritized, bounded hardening actions |
| `APPENDIX-evidence-map.md` | Claim, finding, and verification anchors |
| `review-manifest.json` | Machine-checked provenance declaration |
| `scope.md` | Frozen target snapshot and effective scope |
| `execution-approvals.md` | `APPROVAL-NNN` records for every approved command |
| `evidence-ledger.md` | `SR-20000101-002-fixture-executed-E####` evidence rows |
| `search-log.md`, `open-questions.md`, `inaccessible-resources.md`, `source-discoveries.md` | Process records |
| `publication-checklist.md` | Distribution state and human promotion record |
| `HANDOFF.md` | Restartable position and the human review target |
| `iterations/` | Append-only `REVIEW-ITERATION-NNN` records |

## Bottom line

One Informational finding in a synthetic execution-backed fixture; see `SECURITY-REVIEW.md`.
