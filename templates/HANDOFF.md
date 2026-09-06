<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 James Morris <jamorris@linux.microsoft.com> -->

# Security-review package handoff

Package ID: `@@PACKAGE_ID@@`
Title: @@TITLE@@
Created: @@CREATED@@
Status: `Draft`
Distribution: `private`

## Overall position

The package has been allocated. Intake, discovery, and scope confirmation are
not complete.

## Blockers

- Target state is not frozen.
- Effective scope is not confirmed.
- No evidence has been admitted.

## Next action

Complete guided intake, run the deterministic discovery pass for the confirmed
registered target, and obtain confirmation of the effective scope.

## Exact artifact paths

- Primary projection: `SECURITY-REVIEW.md` and `03-findings.md` (review
  package) or `synthesis.md` and `disposition-ledger.md` (synthesis package)
- Provenance: `review-manifest.json` and `execution-approvals.md` (review
  package only)
- Scope: `scope.md`
- Evidence ledger: `evidence-ledger.md`
- Search record: `search-log.md`
- Open questions: `open-questions.md`

## Human review target

- Target commit: Not recorded.
- Package path: Not recorded.
- Validation command: `scripts/validate-security-review.sh --draft <package>`
- Next human decision: Confirm the effective scope.

## Activity

| Activity ID | Date | Actor | Action | Evidence IDs | Notes |
| --- | --- | --- | --- | --- | --- |
| ACTIVITY-001 | @@CREATED@@ | Security-reviewer | Created the package handoff. | None | Append later activity; do not rewrite history. |
